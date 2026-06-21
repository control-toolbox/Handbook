#!/usr/bin/env julia

"""
Dependency Graph Extractor for control-toolbox ecosystem

This script extracts the dependency graph with versions for CT* packages.
It automatically checks and installs ct-registry if needed.

Usage:
    julia extract-graph.jl                    # Extract graph with current environment
    julia extract-graph.jl v1.1.7-beta        # Extract graph with OptimalControl@v1.1.7-beta
    julia extract-graph.jl 1.1.7-beta         # Also works without 'v' prefix
"""


using Pkg
using Dates

function is_registry_installed(registry_name::String)
    """Check if a registry is installed"""
    registries = Pkg.Registry.reachable_registries()
    return any(r -> r.name == registry_name, registries)
end

function install_ct_registry()
    """Install ct-registry if not already installed"""
    registry_name = "ct-registry"
    registry_url = "https://github.com/control-toolbox/ct-registry.git"

    if is_registry_installed(registry_name)
        println("✓ $registry_name is already installed")
        return true
    end

    println("⚠ $registry_name not found. Installing...")
    try
        Pkg.Registry.add(Pkg.RegistrySpec(url=registry_url))
        println("✓ $registry_name successfully installed")
        return true
    catch e
        println("✗ Failed to install $registry_name: $e")
        return false
    end
end

function setup_local_environment()
    """Setup a local environment in the script directory"""
    script_dir = @__DIR__

    # Activate local environment
    println("Setting up local environment in $script_dir...")
    Pkg.activate(script_dir)

    # Instantiate if needed (install dependencies from Project.toml if it exists)
    if isfile(joinpath(script_dir, "Project.toml"))
        Pkg.instantiate()
    end

    println("✓ Local environment activated\n")
end

function extract_graph_from_pkg(; oc_version::Union{Nothing,String}=nothing)
    """Strategy 1: Use Pkg.dependencies() API"""
    println("=== Strategy 1: Pkg.dependencies() ===\n")

    # If a specific version is requested, add it first
    if !isnothing(oc_version)
        println("Installing OptimalControl@$oc_version in local environment...")
        try
            # Normalize version string (ensure it starts with 'v')
            version_str = startswith(oc_version, "v") ? oc_version : "v" * oc_version

            # For beta/alpha versions, use 'rev' parameter to specify the exact tag
            # This works better than 'version' which expects standard semver
            Pkg.add(Pkg.PackageSpec(name="OptimalControl", rev=version_str))
            println("✓ OptimalControl@$version_str installed successfully\n")
        catch e
            println("✗ Failed to install OptimalControl@$oc_version: $e")
            println("Continuing with current environment...\n")
        end
    end

    deps = Pkg.dependencies()
    ct_pkgs = filter(p -> startswith(p.second.name, "CT") || p.second.name == "OptimalControl", deps)

    # Build graph with dependencies
    graph = Dict()
    for (uuid, pkg) in ct_pkgs
        pkg_deps = []
        if !isnothing(pkg.dependencies)
            for (dep_name, dep_uuid) in pkg.dependencies
                if haskey(deps, dep_uuid) && (startswith(deps[dep_uuid].name, "CT") || deps[dep_uuid].name == "OptimalControl")
                    push!(pkg_deps, (deps[dep_uuid].name, deps[dep_uuid].version))
                end
            end
        end
        graph[pkg.name] = (pkg.version, pkg_deps)
    end

    # Compute dependents (reverse dependencies)
    for (pkg_name, (version, deps)) in graph
        pkg_dependents = []
        for (other_pkg_name, (other_version, other_deps)) in graph
            for (dep_name, dep_version) in other_deps
                if dep_name == pkg_name
                    push!(pkg_dependents, (other_pkg_name, other_version))
                end
            end
        end
        graph[pkg_name] = (version, deps, pkg_dependents)
    end

    return graph
end

function print_graph(graph)
    """Print graph in readable format"""
    # Start with OptimalControl
    if haskey(graph, "OptimalControl")
        version, deps, _ = graph["OptimalControl"]
        println("OptimalControl v$version")
        for (dep_name, dep_version) in deps
            println("  ├── $dep_name v$dep_version")
            if haskey(graph, dep_name)
                _, subdeps, _ = graph[dep_name]
                for (subdep_name, subdep_version) in subdeps
                    println("  │   └── $subdep_name v$subdep_version")
                end
            end
        end
    end

    println("\n=== Full Graph ===\n")
    for (pkg_name, (version, deps, dependents)) in sort(collect(graph))
        println("$pkg_name v$version")
        if !isempty(deps)
            println("  Dependencies:")
            for (dep_name, dep_version) in sort(deps, by = x -> x[1])
                println("    → $dep_name v$dep_version")
            end
        end
        if !isempty(dependents)
            println("  Dependents:")
            for (dep_name, dep_version) in sort(dependents, by = x -> x[1])
                println("    ← $dep_name v$dep_version")
            end
        end
        println()
    end
end

function export_to_markdown(graph, filename="dependency-graph.md")
    """Export graph to markdown format"""
    open(filename, "w") do io
        write(io, "# control-toolbox Dependency Graph\n\n")
        write(io, "**Generated**: $(now())\n\n")
        write(io, "## Tree View\n\n")
        write(io, "```\n")

        if haskey(graph, "OptimalControl")
            version, deps, _ = graph["OptimalControl"]
            write(io, "OptimalControl v$version\n")
            for (i, (dep_name, dep_version)) in enumerate(deps)
                is_last = i == length(deps)
                prefix = is_last ? "└──" : "├──"
                write(io, "  $prefix $dep_name v$dep_version")

                if haskey(graph, dep_name)
                    _, subdeps, _ = graph[dep_name]
                    if !isempty(subdeps)
                        write(io, " →")
                        for (j, (subdep_name, subdep_version)) in enumerate(subdeps)
                            if j == 1
                                write(io, " $subdep_name v$subdep_version")
                            else
                                write(io, ", $subdep_name v$subdep_version")
                            end
                        end
                    end
                end
                write(io, "\n")
            end
        end

        write(io, "```\n\n")
        write(io, "## Package Details\n\n")

        for (pkg_name, (version, deps, dependents)) in sort(collect(graph))
            write(io, "### $pkg_name v$version\n\n")
            if isempty(deps)
                write(io, "No CT dependencies\n\n")
            else
                write(io, "**Dependencies**:\n")
                for (dep_name, dep_version) in sort(deps, by = x -> x[1])
                    write(io, "- $dep_name v$dep_version\n")
                end
                write(io, "\n")
            end
            if !isempty(dependents)
                write(io, "**Dependents**:\n")
                for (dep_name, dep_version) in sort(dependents, by = x -> x[1])
                    write(io, "- $dep_name v$dep_version\n")
                end
                write(io, "\n")
            end
        end
    end
    println("Graph exported to $filename")
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    println("Extracting dependency graph...\n")

    # Setup local environment in script directory
    setup_local_environment()

    # Check and install ct-registry if needed
    install_ct_registry()
    println()

    # Parse command-line arguments for version
    oc_version = nothing
    if length(ARGS) > 0
        oc_version = ARGS[1]
        println("Requested OptimalControl version: $oc_version\n")
    end

    graph = extract_graph_from_pkg(oc_version=oc_version)
    print_graph(graph)
    export_to_markdown(graph)
end
