program test_init_geom
  use numPrecision
  use genericProcedures
  use universalVariables
  use surface_class
  use cell_class
  use universe_class
  use lattice_class
  use initialiseGeometryStructures
  use geometry_class
  use dictionary_class
  use IOdictionary_class
  use datalessMaterials_class, only : datalessMaterials
  use particle_class
  use rng_class
  use transportOperator_inter
  use transportOperatorDT_class
  use transportOperatorST_class
  use mesh_class

  implicit none

  type(geometry) :: geom
  integer(shortInt) :: max_nest, rootInd
  class(surface_ptr), dimension(:), allocatable :: surfaces
  class(cell), dimension(:), allocatable :: cells
  class(universe), dimension(:), allocatable :: universes
  class(lattice), dimension(:), allocatable :: lattices
  type(IOdictionary) :: geomDict
  type(datalessMaterials) :: materials
  real(defReal) :: pitch = 1.0
  real(defReal), dimension(3) :: orgGeom
  integer(shortInt) :: pixels = 1000
  integer(shortInt) :: i,j
  integer(shortInt), dimension(:,:), allocatable :: colourMatrix
  character(100) :: path = './lattice.txt'
  type(particle) :: p
  type(rng) :: rand
  type(cell_ptr) :: c
  type(transportOperatorDT) :: DTOperator
  type(transportOperatorST) :: STOperator
  type(mesh) :: m
  real(defReal) :: angle

  call geomDict % initFrom(path)

  call materials % init(['uo2','mod','big'])
  print *, materials % materials

  call initGeometryFromDict(geom, surfaces, cells, universes, lattices, max_nest, rootInd, geomDict, materials)

  print *,'Plotting geometry'
  allocate(colourMatrix(pixels,pixels))
  !colourMatrix = geom % slicePlot([pixels,pixels],orgGeom,[4.0*pitch,4.0*pitch,2.0*pitch],3)

  do i=1,pixels
    do j=1,pixels
      !print *,colourMatrix(i,j)
    end do
  end do

  !print *,'Preparing transport'
  call p % build([0.2_8,0.0_8,ZERO],[sin(PI*0.9),cos(PI*0.9),ZERO],1,1._8)
  c = geom % whichCell(p % coords)
  !print *,'found which cell'
  call rand % init(500_8)
  call DTOperator % init(rand,geom)
  call STOperator % init(rand,geom)

  ! Initialise mesh to score points
  call m % init([0.02_8,0.02_8,1._8], lattices(1) % corner, [200,200,1], 1, .FALSE.,'m1')

  print *, 'Begin walk'
  do i=1,1000000
    !f (modulo(i,1000) == 0) print *, i
    angle=2*PI*rand % get()
    call p % build([0.0_8,0.0_8,ZERO],[cos(3.0*PI/4),sin(3.0*PI/4),ZERO],1,1._8)
    c = geom % whichCell(p % coords)
    !print *,c%name()
    do while (.not. p % isDead)
      print *,i
      call STOperator % transport(p)
      call m % score(p % rGlobal(), p % dirGlobal())
      if (rand % get() > 0.95) then
        p % isDead = .TRUE.
      else
        angle=2*PI*rand % get()
        call p % point([cos(angle),sin(angle),ZERO])
      end if
    end do
  end do

  do i=1,200
    do j=1,200
      print *, m % density(i,j,1)
    end do
  end do

end program test_init_geom
