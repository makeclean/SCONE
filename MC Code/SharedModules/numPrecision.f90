module numPrecision
  implicit none
  private
  ! Variables Kind and Length parameters
  integer, public, parameter :: defReal = 8,     &
                                shortInt = 4,    &
                                longInt = 8,     &
                                defBool = 4,     &
                                matNameLen = 20, &
                                pathLen = 100,   &
                                zzIdLen = 10,    &
                                lineLen = 300,   &
                                nameLen = 30
  ! I/O error codes
  integer, public, parameter :: endOfFile = -1

  ! Usefull constants
  real(defReal), public, parameter :: PI = 4.0 * atan(1.0_defReal)

contains
    
end module numPrecision
