# Changes

## V0.3, approaching
- Fork -> VoronoiFVM
- Complete rewrite of assembly allowing sparse or dense matrix 
to store degree of freedom information
  - Solution is a nnodes x nspecies sparse or dense matrix
  - The wonderful array interface of Julia still provides slicing
    etc in oder to access  species without need to write
    any bulk_solution stuff or whatever when using the sparse variant
- Re-export value() for debugging in physics functions
- Test function handling
- First working steps to impedance handling
- Abolished Graph in favor of  Grid, Graph was premature optimization...
- More or less zoning in on Voronoi...

## V0.2, Feb 20, 2019

- Changed signature of all callback functions:
  This also allows to pass user defined arrays etc. to the callback functions.
  In particular, velocity vectors can be passed this way.

  - Besides of `flux!()`, they now all have `node::VoronoiFVM.Node`
    as a second argument.

  - `flux!()` has `edge::VoronoiFVM.Edge` as a second argument

  - the `x` argument in `source!()` is omitted, the same data
     are now found in `node.coord`


- New method `edgelength(edge::VoronoiFVM.Edge)`
  
## V0.1, Dec. 2018

- Initial release