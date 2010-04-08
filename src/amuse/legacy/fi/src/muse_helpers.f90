subroutine muse_start
  include 'globals.h'
  real*8 rtime, dum
  logical, save :: firstcall=.TRUE.

  dum = rtime()
  
  if(firstcall) then
    firstcall=.FALSE.

    call initmem(nbodsmax,nsphmax,ncells)

    print*,' '

    print*,' compiled with:'

    if(periodic) then
      print*,' > periodic boundary'
    else
      print*,' > vacuum boundary'
    endif

    if(sortpart) then
      print*,' > particle sorting'
    else
      print*,' > no particle sorting'
    endif

    if(H2cooling) then
      print*,' > h2 cooling'
    else
      print*,' > no h2 cooling'
    endif

    if(ionCool) then
      print*,' > variable ionization'
    else
      print*,' > fixed ionization'
    endif

    if(simpleeff) then
      print*,' > simple heating efficiency'
    else
      print*,' > full heating efficiency'
    endif

    if(cosmrayheat) then
      print*,' > cosmic ray heating'
    else
      print*,' > no cosmic ray heating'
    endif

    if(usepm) then
      print*,' > pm gravity'
    else
      print*,' > no pm gravity'
    endif

    print*,' > compiled constraints:'
    print*,'    no. of particles: ',nbodsmax
    print*,'    no. of sph part:  ',nsphmax
    print*,'    no. of cells:     ',ncells
    print*,' '
  endif

  call set_parameters_to_defaults

! use internal energy integration until things are consistent...
  uentropy=.FALSE.
end subroutine

subroutine muse_init
 include 'globals.h'
 
! call startout

 call check_parameters

 call heattabel

 call initpars
	
 call inithalo

 if(periodic) call initbc

 call initnewstar

end subroutine

subroutine muse_finalize_init
 include 'globals.h'

 if(usepm) then
	 if(verbosity.GT.0) print*,' ...initPM...'
	 call initpm 
 endif
 
 tempvect(1:nsph)=ethermal(1:nsph) 
 call postprocessread
	
 call initpos
	        		
 call outstate(0)


end subroutine

function amuse_synchronize_model() result(ret)
  include 'globals.h'
  integer ret
  real*8 dum1,dum2,dum3
! muse_energies does coorpos if called (1,..)
  call muse_energies(1,dum1,dum2,dum3)
  ret=0
end function    

function muse_reinitialize() result(ret)
  include 'globals.h'
  integer ret
  
  if(syncflag.NE.0) then
    ret=-1
    return
  endif  
  call partremoval
  call initstep
  call zeroacc
  call zeropot
  acc(1:nbodies,4)=0.
  call gravity('both')
  call makesphtree
  call densnhsmooth
! call tree_reduction(root,incells,'sph ')
  if(uentropy) then
    csound(1:nsph)=sqrt(gamma*rho(1:nsph)**gamma1*entropy(1:nsph)) !cosmof3
  else
    csound(1:nsph)=sqrt(gamma*gamma1*ethermal(1:nsph))
  endif
  if(input(34).EQ.0) call starevolv
  if(sortpart) call mortonsort
  call initpos
  print*,' **warning: check results reinit**' 
  ret=0
end function

subroutine muse_reset(time)
 include 'globals.h'
 real time

 nbodies=0
 nsph=0
 nstar=0
 totptag=0
 nbh=0
 
 tnow=0
 mtot=0
 ektot=0
 eptot=0
 snheat=0
 eradiate=0
 esofttot=0
 enerror=0
 estar=0
 efuvheat=0
 eradcool=0
 tpos=tnow
 teth=tnow
 trad=tnow
 if(meanmwt.LE.0) meanmwt=1.
 if(fhydrogn.LE.0) fhydrogn=1.
 massres=0
 tstarform=tnow
 tsnfeedback=tnow
 tbh=tnow
 ttree=tnow-1.
 eps=0. 

 input=0
 input(1:4)=1  ! mass+pos+vel+eps
! input(5)=1    ! tform
 input(42)=1   ! nbexist

 input(11)=1   ! ethermal
 input(13)=0   ! hsmooth
 
end


subroutine muse_end
 include 'globals.h'


end subroutine

subroutine muse_set_time(time)
 include 'globals.h'
 real :: time
 
 tnow=time
 tpos=tnow
 teth=tnow
 trad=tnow
 tstarform=tnow
 tsnfeedback=tnow
 tbh=tnow
 ttree=tnow-1.
   
end subroutine

subroutine muse_add_particle_sph(id,m,x,y,z,vx,vy,vz,e,u,npart)
 include 'globals.h'
 integer :: npart
 integer :: id(npart)
 real :: m(npart),x(npart),y(npart),z(npart), &
  vx(npart),vy(npart),vz(npart),e(npart),u(npart)
 integer addspace_gas
 integer p

 p=addspace_gas(npart)

 mass(p:p+npart-1)=m(1:npart)
 pos(p:p+npart-1,1)=x(1:npart)
 pos(p:p+npart-1,2)=y(1:npart)
 pos(p:p+npart-1,3)=z(1:npart)
 vel(p:p+npart-1,1)=vx(1:npart)
 vel(p:p+npart-1,2)=vy(1:npart)
 vel(p:p+npart-1,3)=vz(1:npart)
 epsgrav(p:p+npart-1)=e(1:npart)
 hsmooth(p:p+npart-1)=e(1:npart)
 ethermal(p:p+npart-1)=u(1:npart)
 ethold(p:p+npart-1)=u(1:npart)
 nbexist(p:p+npart-1)=id(1:npart)

end subroutine

subroutine muse_add_particle_star(id,m,x,y,z,vx,vy,vz,e,tf,npart)
 include 'globals.h'
 integer :: npart
 integer :: id(npart)
 real :: m(npart),x(npart),y(npart),z(npart), &
  vx(npart),vy(npart),vz(npart),e(npart),tf(npart)
 integer addspace_star
 integer p

 p=addspace_star(npart)

 mass(p:p+npart-1)=m(1:npart)
 pos(p:p+npart-1,1)=x(1:npart)
 pos(p:p+npart-1,2)=y(1:npart)
 pos(p:p+npart-1,3)=z(1:npart)
 vel(p:p+npart-1,1)=vx(1:npart)
 vel(p:p+npart-1,2)=vy(1:npart)
 vel(p:p+npart-1,3)=vz(1:npart)
 epsgrav(p:p+npart-1)=e(1:npart)
 tform(p:p+npart-1)=tf(1:npart)
 nbexist(p:p+npart-1)=id(1:npart)

end subroutine


subroutine muse_add_particle_dm(id,m,x,y,z,vx,vy,vz,e,npart)
 include 'globals.h'
 integer :: npart
 integer :: id(npart)
 real :: m(npart),x(npart),y(npart),z(npart), &
  vx(npart),vy(npart),vz(npart),e(npart)
 integer addspace_dm
 integer p

 p=addspace_dm(npart)

 mass(p:p+npart-1)=m(1:npart)
 pos(p:p+npart-1,1)=x(1:npart)
 pos(p:p+npart-1,2)=y(1:npart)
 pos(p:p+npart-1,3)=z(1:npart)
 vel(p:p+npart-1,1)=vx(1:npart)
 vel(p:p+npart-1,2)=vy(1:npart)
 vel(p:p+npart-1,3)=vz(1:npart)
 epsgrav(p:p+npart-1)=e(1:npart)
 nbexist(p:p+npart-1)=id(1:npart)

end subroutine

function muse_get_nbodies() result(n)
 include 'globals.h'
 integer :: n
 n=nbodies
end function 

function muse_get_nsph() result(n)
 include 'globals.h'
 integer :: n
 n=nsph
end function 

function muse_get_nstar() result(n)
 include 'globals.h'
 integer :: n
 n=nstar
end function 

function muse_get_ndm() result(n)
 include 'globals.h'
 integer :: n
 n=nbodies-nsph-nstar
end function 

function muse_get_time_step() result(dt)
 include 'globals.h'
 real :: dt
 dt=dtime
end function 

subroutine muse_stepsys(tend,sync)
 include 'globals.h'
 real :: tend
 integer :: sync
 integer,save :: n=0
 call corrpos(itimestp,'desync')
 do while(tnow<tend)
   call step
   n=n+1
 enddo
 call outstate(n)
 if(sync.EQ.1) call corrpos(itimestp,'sync')
end subroutine

subroutine muse_get_gravity(epsin,x,y,z,ax,ay,az,n)
  include 'globals.h'
 integer :: n,i
 real :: epsin(n),x(n),y(n),z(n) 
 real :: ax(n),ay(n),az(n)
 real :: ppos(3),peps, pacc(3),pphi

 if(tnow.NE.ttree) call maketree 
 do i=1,n
  peps=epsin(i)
  ppos(1)=x(i);ppos(2)=y(i);ppos(3)=z(i)  
  call evaluate_gravity(peps,ppos,pphi,pacc,'acc ')
  ax(i)=pacc(1);ay(i)=pacc(2);az(i)=pacc(3)
 enddo
end subroutine

subroutine muse_get_tidalfield(epsin,x,y,z,tide,n)
  include 'globals.h'
 integer :: n,i
 real :: epsin(n),x(n),y(n),z(n) 
 real :: tide(6,n)
 real :: ppos(3),peps, ptide(6)

 if(tnow.NE.ttree) call maketree 
 do i=1,n
  peps=epsin(i)
  ppos(1)=x(i);ppos(2)=y(i);ppos(3)=z(i)  
  call evaluate_tidalfield(peps,ppos,ptide)
  tide(1:6,i)=ptide(1:6)
 enddo
end subroutine


subroutine muse_get_pot(epsin,x,y,z,pot,n)
  include 'globals.h'
 integer :: n,i
 real :: epsin(n),x(n),y(n),z(n) 
 real :: pot(n)
 real :: ppos(3),peps, pacc(3),pphi

 if(tnow.NE.ttree) call maketree 
 do i=1,n
  peps=epsin(i)
  ppos(1)=x(i);ppos(2)=y(i);ppos(3)=z(i)  
  call evaluate_gravity(peps,ppos,pphi,pacc,'pot ')
  pot(i)=pphi
 enddo
end subroutine


subroutine external_gravity(option)
 include 'globals.h'
 character*4 option
 integer, parameter :: bunchsize=1024
 real :: l_eps(bunchsize), l_pos(bunchsize,3), &
         l_phi(bunchsize), l_acc(bunchsize,3)
 integer i,ndone,todo

 ndone=0
 do while(ndone.LT.npactive)

    todo=MIN(bunchsize,npactive-ndone)

    l_eps(1:todo)=epsgrav(pactive(ndone+1:ndone+todo))
    l_pos(1:todo,1:3)=pos(pactive(ndone+1:ndone+todo),1:3)
    l_acc(1:todo,1:3)=0
    l_phi(1:todo)=0

    select case (option)
    case('acc ')
      call call_external_acc(l_eps(1), &
           l_pos(1,1),l_pos(1,2),l_pos(1,3), &
           l_acc(1,1),l_acc(1,2),l_acc(1,3), todo)
    case('pot ')
      call call_external_pot(l_eps(1), &
             l_pos(1,1),l_pos(1,2),l_pos(1,3), &
             l_phi(1), todo)
    case default
      call call_external_acc(l_eps(1), &
             l_pos(1,1),l_pos(1,2),l_pos(1,3), &
             l_acc(1,1),l_acc(1,2),l_acc(1,3), todo)
      call call_external_pot(l_eps(1), &
             l_pos(1,1),l_pos(1,2),l_pos(1,3), &
             l_phi(1), todo)
    end select

    acc(pactive(ndone+1:ndone+todo),1:3)= &
            acc(pactive(ndone+1:ndone+todo),1:3)+l_acc(1:todo,1:3)	   
    phi(pactive(ndone+1:ndone+todo))= &
            phi(pactive(ndone+1:ndone+todo))+l_phi(1:todo)	   

    ndone=ndone+todo

 enddo

end subroutine

subroutine muse_set_nstar(ns)
 include 'globals.h'
 integer ns
 nstar=ns
end subroutine

subroutine muse_set_nsph(ns)
 include 'globals.h'
 integer ns
 nsph=ns
end subroutine

subroutine muse_energies(mode,ek,ep,eth)
 include 'globals.h'
 real :: ek,ep,eth
 integer :: mode
 
 if(mode.NE.0) then
  call corrpos(itimestp,'sync')
  call zeropot
  call gravity('pot ')
  call diagnostics
 endif
 
 ek=ektot
 ep=eptot
 eth=ethtot
 
end subroutine 

function muse_get_time() result(t)
 include 'globals.h'
 real :: t
 t=tnow
end function 

function muse_get_dynamical_time_scale() result(dt)
 include 'globals.h'
 real dt
 dt=(-0.5*mtot*mtot/eptot) / sqrt(2*ektot/mtot)
end function 
 

function muse_find(id,n,ids,order) result(p)
 integer id,p,n,ids(n),order(n),low,high,k

 low=1
 high=n
 do while(low.LT.high)
   k=low+((high-low)/2)   
   if(ids(order(k)).LT.id) then
      low=k+1
   else
      high=k
   endif 
 enddo
 if(low.LT.n+1.AND.ids(order(low)).EQ.id) then
   p=order(low)
 else
   p=-1
 endif   
end function

function muse_find_particle(tnow,id,n,ids) result(p)
  use hashMod
  integer :: id,n,p,ids(*)
  real*8 :: tnow
  real*8, save :: tstate=-999999.
  
  if(tstate.NE.tnow) then
    call initHash(n/2+1,n,ids) 
    tstate=tnow
  endif  
   
  p=find(id,ids)
   
end function


subroutine muse_get_state(id,m,x,y,z,vx,vy,vz,e)
  include 'globals.h'
  integer :: id,dum,amuse_get_state
  real*8 :: m,x,y,z,vx,vy,vz,e
  dum=amuse_get_state(id,m,x,y,z,vx,vy,vz,e)
end subroutine
 
function amuse_get_state(id,m,x,y,z,vx,vy,vz,e) result(ret)
  include 'globals.h'
  integer :: id,ret,p,muse_find_particle
  real*8 :: m,x,y,z,vx,vy,vz,e

  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif 
  if(nbexist(p).NE.id) call terror("id error 2")
  m=mass(p)
  x=pos(p,1)
  y=pos(p,2)
  z=pos(p,3)
  vx=vel(p,1)
  vy=vel(p,2)
  vz=vel(p,3)
  if(p.LE.nsph) then 
    e=hsmooth(p)
  else
    e=epsgrav(p)
  endif
  ret=0 
end function

function amuse_get_state_sph(id,m,x,y,z,vx,vy,vz,e,u) result(ret)
  include 'globals.h'
  integer :: id,ret,p,muse_find_particle
  real*8 :: m,x,y,z,vx,vy,vz,e,u

  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif 
  if(p.GT.nsph) then
    ret=1
    return
  endif  
  if(nbexist(p).NE.id) call terror("id error 2")
  m=mass(p)
  x=pos(p,1)
  y=pos(p,2)
  z=pos(p,3)
  vx=vel(p,1)
  vy=vel(p,2)
  vz=vel(p,3)
  e=hsmooth(p)
  u=ethermal(p)
  ret=0 
end function

function amuse_get_state_star(id,m,x,y,z,vx,vy,vz,e,tf) result(ret)
  include 'globals.h'
  integer :: id,ret,p,muse_find_particle
  real*8 :: m,x,y,z,vx,vy,vz,e,tf

  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif 
  if(p.LT.nbodies-nstar+1) then
    ret=1
    return
  endif  
  if(nbexist(p).NE.id) call terror("id error 2")
  m=mass(p)
  x=pos(p,1)
  y=pos(p,2)
  z=pos(p,3)
  vx=vel(p,1)
  vy=vel(p,2)
  vz=vel(p,3)
  e=epsgrav(p)
  tf=tform(p)
  ret=0 
end function

function amuse_set_state(id,m,x,y,z,vx,vy,vz,e) result(ret)
  include 'globals.h'
  integer :: id,p,ret,muse_find_particle
  real*8 :: m,x,y,z,vx,vy,vz,e

  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif
  if(nbexist(p).NE.id) call terror("id error 2")
  mass(p)=m
  pos(p,1)=x
  pos(p,2)=y
  pos(p,3)=z
  vel(p,1)=vx
  vel(p,2)=vy
  vel(p,3)=vz
  epsgrav(p)=e
  ret=0 
end function

function amuse_set_state_sph(id,m,x,y,z,vx,vy,vz,e,u) result(ret)
  include 'globals.h'
  integer :: id,p,ret,muse_find_particle
  real*8 :: m,x,y,z,vx,vy,vz,e,u

  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif
  if(p.GT.nsph) then
    ret=-2
    return
  endif  
  if(nbexist(p).NE.id) call terror("id error 2")
  mass(p)=m
  pos(p,1)=x
  pos(p,2)=y
  pos(p,3)=z
  vel(p,1)=vx
  vel(p,2)=vy
  vel(p,3)=vz
  epsgrav(p)=e
  ethermal(p)=u
  ret=0 
end function

function amuse_set_state_star(id,m,x,y,z,vx,vy,vz,e,tf) result(ret)
  include 'globals.h'
  integer :: id,p,ret,muse_find_particle
  real*8 :: m,x,y,z,vx,vy,vz,e,tf

  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif
  if(p.LT.nbodies-nstar+1) then
    ret=-2
    return
  endif  
  if(nbexist(p).NE.id) call terror("id error 2")
  mass(p)=m
  pos(p,1)=x
  pos(p,2)=y
  pos(p,3)=z
  vel(p,1)=vx
  vel(p,2)=vy
  vel(p,3)=vz
  epsgrav(p)=e
  tform(p)=tf
  ret=0 
end function


function muse_remove_particle(id) result(ret)
  include 'globals.h'
  integer :: id,p,ret,muse_find_particle

  if(syncflag.NE.0) then
    ret=-2
    return
  endif  
  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif
  if(nbexist(p).NE.id) call terror("id error 2")
  mass(p)=0.
  ret=0   
end function

function muse_index_of_first_particle(id) result(ret)
  include 'globals.h'
  integer id,ret
  if(nbodies.LT.1) then
    ret=-1
    return
  endif
  id=nbexist(1)
  ret=0
end function

function muse_index_of_next_particle(id,id1) result(ret)
  include 'globals.h'
  integer id,id1,p,ret
  integer muse_find_particle
  if(nbodies.LT.1) then
    ret=-1
    return
  endif
  p=muse_find_particle(tnow,id,nbodies,nbexist)
  if(p.EQ.0) then
    ret=-1
    return
  endif
  if(p.EQ.nbodies) then
    ret=1
    id1=id
    return
  endif    
  id1=nbexist(p+1)
  ret=0
end function

function new_id()
  include 'globals.h'
  integer new_id
  totptag=totptag+1
  new_id=totptag
end function

! parameter setters & getters

! logical
subroutine amuse_set_usesph(x)
  include 'globals.h'
  logical,intent(in) :: x
  usesph=x
end subroutine
subroutine amuse_get_usesph(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=usesph
end subroutine

subroutine amuse_set_radiate(x)
  include 'globals.h'
  logical,intent(in) :: x
  radiate=x
end subroutine
subroutine amuse_get_radiate(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=radiate
end subroutine

subroutine amuse_set_starform(x)
  include 'globals.h'
  logical,intent(in) :: x
  starform=x
end subroutine
subroutine amuse_get_starform(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=starform
end subroutine

subroutine amuse_set_cosmo(x)
  include 'globals.h'
  logical,intent(in) :: x
  cosmo=x
end subroutine
subroutine amuse_get_cosmo(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=cosmo
end subroutine

subroutine amuse_set_sqrttstp(x)
  include 'globals.h'
  logical,intent(in) :: x
  sqrttstp=x
end subroutine
subroutine amuse_get_sqrttstp(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=sqrttstp
end subroutine

subroutine amuse_set_acc_tstp(x)
  include 'globals.h'
  logical,intent(in) :: x
  acc_tstp=x
end subroutine
subroutine amuse_get_acc_tstp(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=acc_tstp
end subroutine

subroutine amuse_set_freetstp(x)
  include 'globals.h'
  logical,intent(in) :: x
  freetstp=x
end subroutine
subroutine amuse_get_freetstp(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=freetstp
end subroutine

subroutine amuse_set_usequad(x)
  include 'globals.h'
  logical,intent(in) :: x
  usequad=x
end subroutine
subroutine amuse_get_usequad(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=usequad
end subroutine

subroutine amuse_set_directsum(x)
  include 'globals.h'
  logical,intent(in) :: x
  directsum=x
end subroutine
subroutine amuse_get_directsum(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=directsum
end subroutine

subroutine amuse_set_selfgrav(x)
  include 'globals.h'
  logical,intent(in) :: x
  selfgrav=x
end subroutine
subroutine amuse_get_selfgrav(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=selfgrav
end subroutine

subroutine amuse_set_fixthalo(x)
  include 'globals.h'
  logical,intent(in) :: x
  fixthalo=x
end subroutine
subroutine amuse_get_fixthalo(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=fixthalo
end subroutine

subroutine amuse_set_adaptive_eps(x)
  include 'globals.h'
  logical,intent(in) :: x
  adaptive_eps=x
end subroutine
subroutine amuse_get_adaptive_eps(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=adaptive_eps
end subroutine

subroutine amuse_set_gdgop(x)
  include 'globals.h'
  logical,intent(in) :: x
  gdgop=x
end subroutine
subroutine amuse_get_gdgop(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=gdgop
end subroutine

subroutine amuse_set_smoothinput(x)
  include 'globals.h'
  logical,intent(in) :: x
  smoothinput=x
end subroutine
subroutine amuse_get_smoothinput(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=smoothinput
end subroutine

subroutine amuse_set_consph(x)
  include 'globals.h'
  logical,intent(in) :: x
  consph=x
end subroutine
subroutine amuse_get_consph(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=consph
end subroutine

subroutine amuse_set_sphinit(x)
  include 'globals.h'
  logical,intent(in) :: x
  sphinit=x
end subroutine
subroutine amuse_get_sphinit(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=sphinit
end subroutine

subroutine amuse_set_uentropy(x)
  include 'globals.h'
  logical,intent(in) :: x
  uentropy=x
end subroutine
subroutine amuse_get_uentropy(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=uentropy
end subroutine

subroutine amuse_set_isotherm(x)
  include 'globals.h'
  logical,intent(in) :: x
  isotherm=x
end subroutine
subroutine amuse_get_isotherm(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=isotherm
end subroutine

subroutine amuse_set_eps_is_h(x)
  include 'globals.h'
  logical,intent(in) :: x
  eps_is_h=x
end subroutine
subroutine amuse_get_eps_is_h(x)
  include 'globals.h'
  logical, intent(out) :: x
  x=eps_is_h
end subroutine



! integer

subroutine amuse_set_firstsnap(x)
  include 'globals.h'
  integer, intent(in) :: x
  firstsnap=x
end subroutine
subroutine amuse_get_firstsnap(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=firstsnap
end subroutine

subroutine amuse_set_stepout(x)
  include 'globals.h'
  integer, intent(in) :: x
  stepout=x
end subroutine
subroutine amuse_get_stepout(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=stepout
end subroutine

subroutine amuse_set_steplog(x)
  include 'globals.h'
  integer, intent(in) :: x
  steplog=x
end subroutine
subroutine amuse_get_steplog(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=steplog
end subroutine

subroutine amuse_set_max_tbin(x)
  include 'globals.h'
  integer, intent(in) :: x
  max_tbin=x
end subroutine
subroutine amuse_get_max_tbin(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=max_tbin
end subroutine

subroutine amuse_set_minppbin(x)
  include 'globals.h'
  integer, intent(in) :: x
  minppbin=x
end subroutine
subroutine amuse_get_minppbin(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=minppbin
end subroutine

subroutine amuse_set_targetnn(x)
  include 'globals.h'
  integer, intent(in) :: x
  targetnn=x
end subroutine
subroutine amuse_get_targetnn(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=targetnn
end subroutine

subroutine amuse_set_verbosity(x)
  include 'globals.h'
  integer, intent(in) :: x
  verbosity=x
end subroutine
subroutine amuse_get_verbosity(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=verbosity
end subroutine

subroutine amuse_set_nsmooth(x)
  include 'globals.h'
  integer, intent(in) :: x
  nsmooth=x
end subroutine
subroutine amuse_get_nsmooth(x)
  include 'globals.h'
  integer, intent(out) :: x
  x=nsmooth
end subroutine


! reals

subroutine amuse_set_pboxsize(x)
  include 'globals.h'
  real*8, intent(in) :: x
  pboxsize=x
end subroutine
subroutine amuse_get_pboxsize(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=pboxsize
end subroutine

subroutine amuse_set_unitm_in_msun(x)
  include 'globals.h'
  real*8, intent(in) :: x
  unitm_in_msun=x
end subroutine
subroutine amuse_get_unitm_in_msun(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=unitm_in_msun
end subroutine

subroutine amuse_set_unitl_in_kpc(x)
  include 'globals.h'
  real*8, intent(in) :: x
  unitl_in_kpc=x
end subroutine
subroutine amuse_get_unitl_in_kpc(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=unitl_in_kpc
end subroutine

subroutine amuse_set_dtime(x)
  include 'globals.h'
  real*8, intent(in) :: x
  dtime=x
end subroutine
subroutine amuse_get_dtime(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=dtime
end subroutine

subroutine amuse_set_tstepcrit(x)
  include 'globals.h'
  real*8, intent(in) :: x
  tstepcrit=x
end subroutine
subroutine amuse_get_tstepcrit(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=tstepcrit
end subroutine

subroutine amuse_set_tstpcr2(x)
  include 'globals.h'
  real*8, intent(in) :: x
  tstpcr2=x
end subroutine
subroutine amuse_get_tstpcr2(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=tstpcr2
end subroutine

subroutine amuse_set_freev(x)
  include 'globals.h'
  real*8, intent(in) :: x
  freev=x
end subroutine
subroutine amuse_get_freev(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=freev
end subroutine

subroutine amuse_set_freea(x)
  include 'globals.h'
  real*8, intent(in) :: x
  freea=x
end subroutine
subroutine amuse_get_freea(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=freea
end subroutine

subroutine amuse_set_freevexp(x)
  include 'globals.h'
  real*8, intent(in) :: x
  freevexp=x
end subroutine
subroutine amuse_get_freevexp(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=freevexp
end subroutine

subroutine amuse_set_freeaexp(x)
  include 'globals.h'
  real*8, intent(in) :: x
  freeaexp=x
end subroutine
subroutine amuse_get_freeaexp(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=freeaexp
end subroutine

subroutine amuse_set_bh_tol(x)
  include 'globals.h'
  real*8, intent(in) :: x
  bh_tol=x
end subroutine
subroutine amuse_get_bh_tol(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=bh_tol
end subroutine

subroutine amuse_set_eps(x)
  include 'globals.h'
  real*8, intent(in) :: x
  eps=x
end subroutine
subroutine amuse_get_eps(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=eps
end subroutine

subroutine amuse_set_gdgtol(x)
  include 'globals.h'
  real*8, intent(in) :: x
  gdgtol=x
end subroutine
subroutine amuse_get_gdgtol(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=gdgtol
end subroutine

subroutine amuse_set_nn_tol(x)
  include 'globals.h'
  real*8, intent(in) :: x
  nn_tol=x
end subroutine
subroutine amuse_get_nn_tol(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=nn_tol
end subroutine

subroutine amuse_set_epsgas(x)
  include 'globals.h'
  real*8, intent(in) :: x
  epsgas=x
end subroutine
subroutine amuse_get_epsgas(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=epsgas
end subroutine

subroutine amuse_set_gamma(x)
  include 'globals.h'
  real*8, intent(in) :: x
  gamma=x
end subroutine
subroutine amuse_get_gamma(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=gamma
end subroutine

subroutine amuse_set_alpha(x)
  include 'globals.h'
  real*8, intent(in) :: x
  alpha=x
end subroutine
subroutine amuse_get_alpha(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=alpha
end subroutine

subroutine amuse_set_beta(x)
  include 'globals.h'
  real*8, intent(in) :: x
  beta=x
end subroutine
subroutine amuse_get_beta(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=beta
end subroutine

subroutine amuse_set_epssph(x)
  include 'globals.h'
  real*8, intent(in) :: x
  epssph=x
end subroutine
subroutine amuse_get_epssph(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=epssph
end subroutine

subroutine amuse_set_courant(x)
  include 'globals.h'
  real*8, intent(in) :: x
  courant=x
end subroutine
subroutine amuse_get_courant(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=courant
end subroutine

subroutine amuse_set_removgas(x)
  include 'globals.h'
  real*8, intent(in) :: x
  removgas=x
end subroutine
subroutine amuse_get_removgas(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=removgas
end subroutine

subroutine amuse_set_consthsm(x)
  include 'globals.h'
  real*8, intent(in) :: x
  consthsm=x
end subroutine
subroutine amuse_get_consthsm(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=consthsm
end subroutine

subroutine amuse_set_nsmtol(x)
  include 'globals.h'
  real*8, intent(in) :: x
  nsmtol=x
end subroutine
subroutine amuse_get_nsmtol(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=nsmtol
end subroutine

subroutine amuse_set_graineff(x)
  include 'globals.h'
  real*8, intent(in) :: x
  graineff=x
end subroutine
subroutine amuse_get_graineff(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=graineff
end subroutine

subroutine amuse_set_crionrate(x)
  include 'globals.h'
  real*8, intent(in) :: x
  crionrate=x
end subroutine
subroutine amuse_get_crionrate(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=crionrate
end subroutine

subroutine amuse_set_heat_par1(x)
  include 'globals.h'
  real*8, intent(in) :: x
  heat_par1=x
end subroutine
subroutine amuse_get_heat_par1(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=heat_par1
end subroutine

subroutine amuse_set_heat_par2(x)
  include 'globals.h'
  real*8, intent(in) :: x
  heat_par2=x
end subroutine
subroutine amuse_get_heat_par2(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=heat_par2
end subroutine

subroutine amuse_set_cool_par(x)
  include 'globals.h'
  real*8, intent(in) :: x
  cool_par=x
end subroutine
subroutine amuse_get_cool_par(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=cool_par
end subroutine

subroutine amuse_set_optdepth(x)
  include 'globals.h'
  real*8, intent(in) :: x
  optdepth=x
end subroutine
subroutine amuse_get_optdepth(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=optdepth
end subroutine

subroutine amuse_set_tcollfac(x)
  include 'globals.h'
  real*8, intent(in) :: x
  tcollfac=x
end subroutine
subroutine amuse_get_tcollfac(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=tcollfac
end subroutine

subroutine amuse_set_masscrit(x)
  include 'globals.h'
  real*8, intent(in) :: x
  masscrit=x
end subroutine
subroutine amuse_get_masscrit(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=masscrit
end subroutine

subroutine amuse_set_sfeff(x)
  include 'globals.h'
  real*8, intent(in) :: x
  sfeff=x
end subroutine
subroutine amuse_get_sfeff(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=sfeff
end subroutine

subroutine amuse_set_tbubble(x)
  include 'globals.h'
  real*8, intent(in) :: x
  tbubble=x
end subroutine
subroutine amuse_get_tbubble(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=tbubble
end subroutine

subroutine amuse_set_sne_eff(x)
  include 'globals.h'
  real*8, intent(in) :: x
  sne_eff=x
end subroutine
subroutine amuse_get_sne_eff(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=sne_eff
end subroutine

subroutine amuse_set_tsnbeg(x)
  include 'globals.h'
  real*8, intent(in) :: x
  tsnbeg=x
end subroutine
subroutine amuse_get_tsnbeg(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=tsnbeg
end subroutine

subroutine amuse_set_rhomax(x)
  include 'globals.h'
  real*8, intent(in) :: x
  rhomax=x
end subroutine
subroutine amuse_get_rhomax(x)
  include 'globals.h'
  real*8, intent(out) :: x
  x=rhomax
end subroutine


! character

subroutine amuse_set_halofile(x)
  include 'globals.h'
  character(len=30), intent(in) :: x
  halofile=x
end subroutine
subroutine amuse_get_halofile(x)
  include 'globals.h'
  character(len=30), intent(out) :: x
  x=halofile
end subroutine

subroutine amuse_set_feedback(x)
  include 'globals.h'
  character(len=4), intent(in) :: x
  feedback=x
end subroutine
subroutine amuse_get_feedback(x)
  include 'globals.h'
  character(len=4), intent(out) :: x
  x=feedback
end subroutine

subroutine amuse_set_sfmode(x)
  include 'globals.h'
  character(len=10), intent(in) :: x
  sfmode=x
end subroutine
subroutine amuse_get_sfmode(x)
  include 'globals.h'
  character(len=10), intent(out) :: x
  x=sfmode
end subroutine

subroutine amuse_set_hupdatemethod(x)
  include 'globals.h'
  character(len=4), intent(in) :: x
  hupdatemethod=x
end subroutine
subroutine amuse_get_hupdatemethod(x)
  include 'globals.h'
  character(len=4), intent(out) :: x
  x=hupdatemethod
end subroutine

subroutine amuse_set_sph_visc(x)
  include 'globals.h'
  character(len=4), intent(in) :: x
  sph_visc=x
end subroutine
subroutine amuse_get_sph_visc(x)
  include 'globals.h'
  character(len=4), intent(out) :: x
  x=sph_visc
end subroutine
