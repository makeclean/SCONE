module pointSource_class

  use numPrecision
  use universalVariables, only: OUTSIDE_MAT
  use genericProcedures,  only: fatalError
  use particle_class,     only: particleState, P_NEUTRON, P_PHOTON
  use dictionary_class,   only: dictionary
  use source_inter,       only: source
  use geometry_inter,     only: geometry
  use RNG_class,          only: RNG  

  implicit none
  private

  !!
  !! Class describing point-like particle sources
  !!
  !! Generates a mono-energetic, mono-directional or isotropic particle 
  !! source from a single point in space, with particles of a single type
  !!
  !! Private members:
  !!   r            -> source position
  !!   dir          -> optional source direction
  !!   E            -> source energy
  !!   G            -> source energy group
  !!   particleType -> source particle type
  !!   isMG         -> is the source multi-group?
  !!   isIsotropic  -> is the source isotropic?
  !!
  !! Interface:
  !!   init              -> initialise point source
  !!   sampleType        -> set particle type
  !!   samplePosition    -> set particle position
  !!   sampleEnergy      -> set particle energy
  !!   sampleEnergyAngle -> sample particle angle
  !!   kill              -> terminate source
  !!
  type, public,extends(source) :: pointSource
    private
    real(defReal),dimension(:), allocatable :: r
    real(defReal),dimension(:), allocatable :: dir
    real(defReal)                           :: E
    integer(shortInt)                       :: G
    integer(shortInt)                       :: particleType
    logical(defBool)                        :: isMG = .false.
    logical(defBool)                        :: isIsotropic
  contains
    procedure :: init
    procedure :: sampleType
    procedure :: samplePosition
    procedure :: sampleEnergy
    procedure :: sampleEnergyAngle
    procedure :: kill
  end type pointSource

contains

  !!
  !! Initialise point source
  !!
  !! Read dictionary to obtain source information and provide
  !! geometry to allow basic check
  !!
  !! Args:
  !!   dict [in] -> dict containing point source information
  !!   geom [in] -> pointer to geometry, used here only for checking
  !!                that source is inside geometry
  !!
  !! Result:
  !!   An initialised point source
  !!
  !! Errors:
  !!   - error if an unrecognised particle type is provided
  !!   - error if source is not inside geometry
  !!   - error if either direction or position have more than 3 components
  !!   - error if both CE and MG is specified
  !!   - error if neither energy type is specified
  !!
  subroutine init(self, dict, geom)
    class(pointSource), intent(inout)    :: self
    class(dictionary), intent(in)        :: dict
    class(geometry), pointer, intent(in) :: geom
    character(30)                        :: type
    integer(shortInt)                    :: matIdx, uniqueID
    logical(defBool)                     :: isCE, isMG, hasDir
    character(100), parameter :: Here = 'init (pointSource_class.f90)'

    ! Provide geometry info to source
    self % geom => geom

    ! Identify which particle is used in the source
    ! Presently limited to neutron and photon
    call dict % getOrDefault(type, 'particle' ,'neutron')
    select case(type)
      case('neutron')
        self % particleType = P_NEUTRON

      case('photon')
        self % particleType = P_PHOTON

      case default
        call fatalError(Here, 'Unrecognised particle type')
     
    end select

    ! Get position and check it's inside geometry
    call dict % get(self % r, 'r') 
    if (size(self % r) /= 3) then
      call fatalError(Here, 'Source position must have three components')
    end if

    call self % geom % whatIsAt(self % r, matIdx, uniqueID)
    if (matIdx == OUTSIDE_MAT) then
      call fatalError(Here, 'Source has been placed outside geometry')
    end if

    ! Get beam direction and normalise - otherwise, assume isotropic
    hasDir = dict % isPresent('dir')
    if (hasDir) then
      
      call dict % get(self % dir, 'dir')
      if (size(self % dir) /= 3) then
        call fatalError(Here, 'Source direction must have three components')
      end if

      self % dir = self % dir / norm2(self % dir)
      self % isIsotropic = .false.

    else
      self % isIsotropic = .true.
    end if

    ! Get particle energy/group
    isCE = dict % isPresent('E')
    isMG = dict % isPresent('G')
    if (isCE .and. isMG) then
      call fatalError(Here, 'Source may be either continuous energy or MG, not both')
    elseif (isCE) then
      call dict % get(self % E, 'E')
    elseif (isMG)
      call dict % get(self % G, 'G')
      self % isMG = .true.
    else
      call fatalError(Here, 'Must specify source energy, either CE or MG')
    end if
 
  end subroutine init

  !!
  !! Provide particle type
  !!
  !! Particle type is fixed on initialisation, this routine simply passes the particle type
  !!
  !! Inputs:
  !!   p [inout] -> particle to be given a type
  !!   rand [in] -> pointer to random number generator
  !!
  !! Result:
  !!   Particle is provided with a type
  !!
  subroutine sampleType(self, p, rand)
    class(pointSource), intent(inout)   :: self
    class(particleState), intent(inout) :: p
    class(RNG), pointer, intent(in)     :: rand 
    
    p % type = self % particleType

  end subroutine sampleType

  !!
  !! Provide particle position
  !!
  !! Particle location is fixed on initialisation, this routine simply passes the location
  !!
  !! Inputs:
  !!   p [inout] -> particle to be given a position
  !!   rand [in] -> pointer to random number generator
  !!
  !! Result:
  !!   Particle is provided with a position
  !!
  subroutine samplePosition(self, p, rand)
    class(pointSource), intent(inout)   :: self
    class(particleState), intent(inout) :: p
    class(RNG), pointer, intent(in)     :: rand 

    p % r = self % r

  end subroutine samplePosition
 
  !!
  !! Provide angle or sample if isotropic
  !!
  !! Particle direction is either fixed or isotropic
  !! This subroutine either passes the direction or samples from the unit sphere
  !!
  !! Inputs:
  !!   p [inout] -> particle to be given a direction
  !!   rand [in] -> pointer to random number generator
  !!
  !! Result:
  !!   Particle is provided with a direction
  !!
  subroutine sampleEnergyAngle(self, p, rand)
    class(pointSource), intent(inout)   :: self
    class(particleState), intent(inout) :: p
    class(RNG), pointer, intent(in)     :: rand 
    real(defReal)                       :: r, phi, theta
    
    if (self % isIsotropic) then
      r = rand % get()
      phi = TWO * PI * r
      r = rand % get()
      theta = acos(1 - TWO * r)
      p % dir = [cos(phi) * sin(theta), sin(phi) * sin(theta), cos(theta)]
    else
      p % dir = self % dir
    end if

  end subroutine sampleEnergyAngle


  !!
  !! Provide particle energy
  !!
  !! Particle energy is fixed - subroutine simply provides it
  !! Applies to either CE or MG particles
  !!
  !! Inputs:
  !!   p [inout] -> particle to be given an energy
  !!   rand [in] -> pointer to random number generator
  !!
  !! Result:
  !!   Particle is provided with an energy
  !!
  subroutine sampleEnergy(self, p, rand)
    class(pointSource), intent(inout)   :: self
    class(particleState), intent(inout) :: p
    class(RNG), pointer, intent(in)     :: rand 

    if (self % isMG) then
      p % G = self % G
      p % isMG = .true.
    else
      p % E = self % E
      p % isMG = .false.
    end if

  end subroutine sampleEnergy

  !!
  !! Terminate point source
  !!
  !! Cleans up geometry pointer
  !!
  subroutine kill(self)
    class(pointSource), intent(inout) :: self

    self % geom => null()

  end subroutine kill

end module pointSource_class
