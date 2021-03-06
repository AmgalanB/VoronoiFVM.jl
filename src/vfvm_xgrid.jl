"""
````
Grid=ExtendableGrids.simplexgrid
````
Re-Export of ExtendableGrids.simplexgrid
"""
const Grid = ExtendableGrids.simplexgrid


num_cellregions(grid::ExtendableGrid)=grid[NumCellRegions]
num_bfaceregions(grid::ExtendableGrid)=grid[NumBFaceRegions]
num_edges(grid::ExtendableGrid)=haskey(grid,EdgeNodes) ?  num_sources(grid[EdgeNodes]) : 0

cellregions(grid::ExtendableGrid)= grid[CellRegions]
bfaceregions(grid::ExtendableGrid)= grid[BFaceRegions]
cellnodes(grid::ExtendableGrid)= grid[CellNodes]
bfacenodes(grid::ExtendableGrid)= grid[BFaceNodes]
coordinates(grid::ExtendableGrid)= grid[Coordinates]



function cartesian!(grid::ExtendableGrid)
    if dim_space(grid)==1
        grid[CoordinateSystem]=Cartesian1D
    elseif dim_space(grid)==2
        grid[CoordinateSystem]=Cartesian2D
    else dim_space(grid)==3
        grid[CoordinateSystem]=Cartesian3D
    end
    return grid
end


function circular_symmetric!(grid::ExtendableGrid)
    if dim_space(grid)==1
        grid[CoordinateSystem]=Polar1D
    elseif dim_space(grid)==2
        grid[CoordinateSystem]=Cylindrical2D
    else
        throw(DomainError(3,"Unable to handle circular symmetry for 3D grid"))
    end
    return grid
end

function spherical_symmetric!(grid::ExtendableGrid)
    d=dim_space(grid)
    if d==1
        grid[CoordinateSystem]=Spherical1D
    else
        throw(DomainError(d,"Unable to handle spherical symmetry for $(d)D grid"))
    end
    return grid
end


"""
$(SIGNATURES)

Prepare edge adjacencies (celledges, edgecells, edgenodes)
""" 
abstract type CellEdges  <: AbstractGridAdjacency end
abstract type EdgeCells  <: AbstractGridAdjacency end
abstract type EdgeNodes <: AbstractGridAdjacency end



function prepare_edges!(grid::ExtendableGrid)
    Ti=eltype(grid[CellNodes])
    cellnodes=grid[CellNodes]
    geom=grid[CellGeometries][1]
    # Create cell-node incidence matrix
    ext_cellnode_adj=ExtendableSparseMatrix{Ti,Ti}(num_nodes(grid),num_cells(grid))
    for icell=1:num_cells(grid)
        for inode=1:num_nodes(geom)
            ext_cellnode_adj[cellnodes[inode,icell],icell]=1
        end
    end
    flush!(ext_cellnode_adj)
    # Get SparseMatrixCSC from the ExtendableMatrix
    cellnode_adj=ext_cellnode_adj.cscmatrix
    
    # Create node-node incidence matrix for neigboring
    # nodes. 
    nodenode_adj=cellnode_adj*transpose(cellnode_adj)

    # To get unique edges, we set the lower triangular part
    # including the diagonal to 0
    for icol=1:length(nodenode_adj.colptr)-1
        for irow=nodenode_adj.colptr[icol]:nodenode_adj.colptr[icol+1]-1
            if nodenode_adj.rowval[irow]>=icol
                nodenode_adj.nzval[irow]=0
            end
        end
    end
    dropzeros!(nodenode_adj)


    # Now we know the number of edges and
    nedges=length(nodenode_adj.nzval)

    
    if dim_space(grid)==2
        # Let us do the Euler test (assuming no holes in the domain)
        v=num_nodes(grid)
        e=nedges
        f=num_cells(grid)+1
        @assert v-e+f==2
    end
    if dim_space(grid)==1
        @assert nedges==num_cells(grid)
    end
    
    # Calculate edge nodes and celledges
    edgenodes=zeros(Ti,2,nedges)
    celledges=zeros(Ti,3,num_cells(grid))
    cen=local_celledgenodes(Triangle2D)
    
    for icell=1:num_cells(grid)
        for iedge=1:num_edges(geom)
            n1=cellnodes[cen[1,iedge],icell]
            n2=cellnodes[cen[2,iedge],icell]

            # We need to look in nodenod_adj for upper triangular part entries
            # therefore, we need to swap accordingly before looking
	    if (n1<n2)
		n0=n1
		n1=n2
		n2=n0;
	    end
            
            for irow=nodenode_adj.colptr[n1]:nodenode_adj.colptr[n1+1]-1
                if nodenode_adj.rowval[irow]==n2
                    # If the coresponding entry has been found, set its
                    # value. Note that this introduces a different edge orientation
                    # compared to the one found locally from cell data
                    celledges[iedge,icell]=irow
                    edgenodes[1,irow]=n1
                    edgenodes[2,irow]=n2
                end
            end
        end
    end


    # Create sparse incidence matrix for the cell-edge adjacency
    ext_celledge_adj=ExtendableSparseMatrix{Ti,Ti}(nedges,num_cells(grid))
    for icell=1:num_cells(grid)
        for iedge=1:num_edges(geom)
            ext_celledge_adj[celledges[iedge,icell],icell]=1
        end
    end
    flush!(ext_celledge_adj)
    celledge_adj=ext_celledge_adj.cscmatrix

    # The edge cell matrix is the transpose
    edgecell_adj=SparseMatrixCSC(transpose(celledge_adj))

    # Get the adjaency array from the matrix
    edgecells=zeros(Ti,2,nedges)
    for icol=1:length(edgecell_adj.colptr)-1
        ii=1
        for irow=edgecell_adj.colptr[icol]:edgecell_adj.colptr[icol+1]-1
            edgecells[ii,icol]=edgecell_adj.rowval[irow]
            ii+=1
        end
    end
    
    grid[EdgeCells]=edgecells
    grid[CellEdges]=celledges
    grid[EdgeNodes]=edgenodes
    true
end

ExtendableGrids.instantiate(grid, ::Type{CellEdges})=prepare_edges!(grid) && grid[CellEdges]
ExtendableGrids.instantiate(grid, ::Type{EdgeCells})=prepare_edges!(grid) && grid[EdgeCells]
ExtendableGrids.instantiate(grid, ::Type{EdgeNodes})=prepare_edges!(grid) && grid[EdgeNodes]
