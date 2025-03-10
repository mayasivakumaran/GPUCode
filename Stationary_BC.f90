PROGRAM MAIN
  USE,INTRINSIC::ISO_FORTRAN_ENV
  IMPLICIT NONE
  INTEGER,PARAMETER::rd=REAL64
  INTEGER::Jind,k
  INTEGER::i,j,imax,ind,Rand,t,m
  REAL(KIND=rd)::Rhoref,Uref,Pref,Eref,Lref,L,R,Cp,Cv
  REAL(KIND=rd)::xmax,xmin,rhoin,rhoout,uin,Uout,Pin,Pout,Cin,Cout,gam
  REAL(KIND=rd)::Dx,dt,Machin,Machout,Tin
  REAL(KIND=rd),DIMENSION(:,:),ALLOCATABLE::Qconv0,Qconv,Favg,Diss
  CHARACTER(len=32)::Sfilename,iter,fmt
  CHARACTER(len=64)::filename2
  CHARACTER(len=:),ALLOCATABLE::Lapsefile

  !Opening Files For Data
  open(1,file='Convergence.dat')

  Sfilename="./Solutions/Solution"
  Rand=len(trim(Sfilename))
  allocate(character(len=Rand) :: LapseFile)
  LapseFile=trim(Sfilename)

  !!
  !Initial Values And Ref Values
  !!
  L=1.0_rd
  xmin=0.0_rd
  xmax=1.0_rd
  imax=1000
  ALLOCATE(Qconv0(3,imax),Qconv(3,imax),Favg(3,imax),Diss(3,imax))  
  gam=1.4_rd
  Cv=0.718_rd
  Cp=1._rd
  R=Cp-Cv
  Tin=273.15_rd
  dt=0.0001_rd

  Rhoin=1.0_rd
  Machin=2.95_rd
  Cin=1.0_rd
  Uin=2.95_rd
  Pin=1.0_rd
  Rhoout=3.8106_rd
  Machout=0.4782_rd
  Cout=1.62_rd
  Uout=MachOut*Cout
  Pout=9.9862_rd
  Dx=(xmax-xmin)/(imax)

  uref=sqrt(gam*Pin/rhoin)
  Lref=L
  rhoref=rhoin
  Pref=rhoin*Cin**2._rd
  Eref=Cv*Tin

  !!
  !Create Initial Solution/Grid
  !!
  !Left
  do i=1,int(imax/2)
     Qconv0(1,i)=Rhoin
     Qconv0(2,i)=2.95_rd
     Qconv0(3,i)=(Pin/gam)/(gam-1)+0.5_rd*rhoin*(Uin**2._rd)
  enddo
  !Right
  do i=(int(imax/2)+1),imax
     Qconv0(1,i)=Rhoout
     Qconv0(2,i)=2.95_rd
     Qconv0(3,i)=(Pout/gam)/(gam-1)+RhoOut*0.5_rd*(Uout**2._rd)
  enddo

  do i=1,imax
     do j=1,3
        Qconv(j,i)=Qconv0(j,i)
     enddo
  enddo

  open(2,file='./Solutions/SolutionStep_0000.dat')
  do ind=1,imax,1
     write(2,*)Qconv0(1,ind),Qconv0(2,ind),Qconv0(3,ind)
  enddo

  !!
  !Start Time Loop
  !!
  !  do t=1,200000
  do t=1,2000000

     if (mod(t,100) .eq. 0) then
        print*,'doing t=',t
     endif


     CALL SuperSonicInflowBC(Qconv0,Favg,Diss,1)
     do i=2,imax-1
        CALL INTERFACES(Qconv0,Favg,Diss,i)
     enddo
     CALL SubSonicOutflowBC(Qconv0,Favg,Diss,imax) 

     do i=2,imax
        do j=1,3
           Qconv(j,i)=Qconv0(j,i)-(dt/dx)*((Favg(j,i)-0.5_rd*Diss(j,i))-&
                (Favg(j,i-1)-0.5_rd*Diss(j,i-1)))
        enddo
     enddo

     !Writing Solution To File
     !Density, rho*u, Et
     if (mod(t,250000)==0) then
        fmt='(I10.10)'
        write(iter,fmt)t
        filename2=Lapsefile(1:Rand)//'Step_'//trim(iter)//".dat"
        open(t+10,file=filename2)
        do ind=1,imax,1
           write(t+10,*)Qconv0(1,ind),Qconv0(2,ind),Qconv0(3,ind)
        enddo
        close(t+10)
     endif
     !Convergence Criteria
     !write(1,*)maxval(abs(Qconv(1,:)-Qconv0(1,:))),maxval(abs(Qconv(2,:)-Qconv0(2,:))),maxval(abs(Qconv(3,:)-Qconv0(3,:)))

     !Print Values
     !Write(6,*)'---------------------------Step'//trim(iter)//'-------------------------'
     !write(6,*)'Max'
     !write(6,*)Maxval(Qconv0(1,:)),Maxval(Qconv0(2,:)),Maxval(Qconv0(3,:))
     !write(6,*)'Min'
     !write(6,*)Minval(Qconv0(1,:)),Minval(Qconv0(2,:)),Minval(Qconv0(3,:))
     !write(6,*)'Dissipation Max'
     !write(6,*)Maxval(Diss(1,:)),Maxval(Diss(2,:)),Maxval(Diss(3,:))
     !write(6,*)'Favg Max'
     !write(6,*)Maxval(Favg(1,:)),Maxval(Favg(2,:)),Maxval(Favg(3,:))

     !Reset Matrices
     do m=2,imax-1
        do j=1,3
           Qconv0(j,m)=Qconv(j,m)
        enddo
     enddo

     !End Time Loop
  enddo
  close(1)

END PROGRAM MAIN

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!SUBROUTINE 1
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SUBROUTINE INTERFACES(Q,Favgin,Dissp,Iind)
USE,INTRINSIC::ISO_FORTRAN_ENV
IMPLICIT NONE
INTEGER,PARAMETER::rd=REAL64
INTEGER,INTENT(IN)::Iind
INTEGER::Jind,k
REAL(KIND=rd),DIMENSION(3,100),INTENT(IN)::Q
REAL(KIND=rd),DIMENSION(3,100),INTENT(INOUT)::Favgin,Dissp
REAL(KIND=rd)::UL,UR,PL,PR,HL,HR,RhoL,RhoR,EL,ER
REAL(KIND=rd)::Rhoroe,Croe,Uroe,Hroe,gam
REAL(KIND=rd),DIMENSION(3)::Lambda,Alpha
REAL(KIND=rd),DIMENSION(3,3)::Eig


gam=1.4_rd
!!!Defining Roe Variables
!By interface sides, left left, left right etc.
RhoL=Q(1,Iind)
RhoR=Q(1,Iind+1)
UL=Q(2,Iind)/Q(1,Iind)
UR=Q(2,Iind+1)/Q(1,Iind+1)
EL=Q(3,Iind)/Q(1,Iind)
ER=Q(3,Iind+1)/Q(1,Iind+1)
PL=(RhoL*EL-0.5_rd*RhoL*(UL**2._rd))*(gam-1.0_rd)
PR=(RhoR*ER-0.5_rd*RhoR*(UR**2._rd))*(gam-1.0_rd)
HL=EL+PL/RhoL
HR=ER+PR/RhoR

!!!Defining Left and Right Fluxes at Both Interfaces
Favgin(1,Iind)=0.5_rd*(RhoR*UR+RhoL*UL)
Favgin(2,Iind)=0.5_rd*(RhoR*(UR**2)+PR+RhoL*(UL**2)+PL)
Favgin(3,Iind)=0.5_rd*(RhoR*UR*HR+RhoL*UL*HL)

!!!Roe Variables At Interface
Rhoroe=sqrt(RhoL*RhoR)
Uroe=(sqrt(RhoL)*UL+sqrt(RhoR)*UR)/(sqrt(RhoL)+sqrt(RhoR))
Hroe=(sqrt(RhoL)*HL+sqrt(RhoR)*HR)/(sqrt(RhoL)+sqrt(RhoR))
Croe=sqrt((gam-1_rd)*(Hroe-0.5_rd*(Uroe**2._rd))) 

!!!Defining eigenvectors
!Eigenvalues
Lambda(1)=Uroe-Croe
Lambda(2)=Uroe
Lambda(3)=Uroe+Croe
!Right Interface
Eig(1,1)=1.0_rd
Eig(2,1)=Uroe-Croe
Eig(3,1)=Hroe-Uroe*Croe 

Eig(1,2)=1.0_rd
Eig(2,2)=Uroe
Eig(3,2)=0.5_rd*Uroe**2._rd

Eig(1,3)=1.0_rd
Eig(2,3)=Uroe+Croe
Eig(3,3)=Hroe+Uroe*Croe

Alpha(1)=(0.25_rd*Uroe/Croe)*(RhoR-RhoL)*(2._rd+(gam-1._rd)*Uroe/Croe)-&
        (0.5_rd/Croe)*(1._rd+(gam-1._rd)*Uroe/Croe)*(RhoR*UR-RhoL*UL)+&
        0.5_rd*(gam-1._rd)*(RhoR*ER-RhoL*EL)/(Croe**2._rd)

Alpha(2)=(1._rd-0.5_rd*((Uroe/Croe)**2._rd)*(gam-1._rd))*(RhoR-RhoL)+&
        (gam-1._rd)*Uroe*(RhoR*UR-RhoL*UL)/(Croe**2._rd)-&
        (gam-1._rd)/(Croe**2._rd)*(RhoR*ER-RhoL*EL)

Alpha(3)=-(0.25_rd*Uroe/Croe)*(2._rd-(gam-1._rd)*Uroe/Croe)*(RhoR-RhoL)+&
        (0.5_rd/Croe)*(1._Rd-(gam-1._rd)*Uroe/Croe)*(RhoR*UR-RhoL*UL)+&
        0.5_rd*(gam-1._rd)*(RhoR*ER-RhoL*EL)/(Croe**2._rd)


Dissp(1,Iind)=abs(lambda(1))*Alpha(1)*Eig(1,1)+abs(lambda(2))*Alpha(2)*Eig(1,2)+&
abs(lambda(3))*Alpha(3)*Eig(1,3)
Dissp(2,Iind)=abs(lambda(1))*Alpha(1)*Eig(2,1)+abs(lambda(2))*Alpha(2)*Eig(2,2)+&
abs(lambda(3))*Alpha(3)*Eig(2,3)
Dissp(3,Iind)=abs(lambda(1))*Alpha(1)*Eig(3,1)+abs(lambda(2))*Alpha(2)*Eig(3,2)+&
abs(lambda(3))*Alpha(3)*Eig(3,3)

END SUBROUTINE INTERFACES

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!SUBROUTINE 2
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SUBROUTINE SuperSonicInflowBC(Q,Favgin,Dissp,Iind)
USE,INTRINSIC::ISO_FORTRAN_ENV
IMPLICIT NONE
INTEGER,PARAMETER::rd=REAL64
INTEGER,INTENT(IN)::Iind
INTEGER::Jind,k
REAL(KIND=rd),DIMENSION(3,100),INTENT(IN)::Q
REAL(KIND=rd),DIMENSION(3,100),INTENT(INOUT)::Favgin,Dissp
REAL(KIND=rd)::UL,UR,PL,PR,HL,HR,RhoL,RhoR,EL,ER
REAL(KIND=rd)::Rhoroe,Croe,Uroe,Hroe,gam
REAL(KIND=rd)::MACH,Pstag,Rhostag,a,Mstag
REAL(KIND=rd),DIMENSION(3)::Lambda,Alpha
REAL(KIND=rd),DIMENSION(3,3)::Eig


gam=1.4_rd
!!!Defining Roe Variables
!By interface sides, left left, left right etc.
RhoL=1.0_rd
RhoR=Q(1,Iind+1)
UL=2.95_rd
UR=Q(2,Iind+1)/Q(1,Iind+1)
EL=(1.0_rd/gam)/(gam-1)+0.5_rd*(RhoL*UL**2._rd)
ER=Q(3,Iind+1)/Q(1,Iind+1)
PL=1.0_rd/gam
PR=(RhoR*ER-0.5_rd*RhoR*(UR**2._rd))*(gam-1.0_rd)
HL=EL+PL/RhoL
HR=ER+PR/RhoR

!!!Defining Left and Right Fluxes at Both Interfaces
Favgin(1,Iind)=0.5_rd*(RhoR*UR+RhoL*UL)
Favgin(2,Iind)=0.5_rd*(RhoR*(UR**2)+PR+RhoL*(UL**2)+PL)
Favgin(3,Iind)=0.5_rd*(RhoR*UR*HR+RhoL*UL*HL)

!!!Roe Variables At Interface
Rhoroe=sqrt(RhoL*RhoR)
Uroe=(sqrt(RhoL)*UL+sqrt(RhoR)*UR)/(sqrt(RhoL)+sqrt(RhoR))
Hroe=(sqrt(RhoL)*HL+sqrt(RhoR)*HR)/(sqrt(RhoL)+sqrt(RhoR))
Croe=sqrt((gam-1_rd)*(Hroe-0.5_rd*(Uroe**2._rd))) 

!!!Defining eigenvectors
!Eigenvalues
Lambda(1)=Uroe-Croe
Lambda(2)=Uroe
Lambda(3)=Uroe+Croe
!Right Interface
Eig(1,1)=1.0_rd
Eig(2,1)=Uroe-Croe
Eig(3,1)=Hroe-Uroe*Croe 

Eig(1,2)=1.0_rd
Eig(2,2)=Uroe
Eig(3,2)=0.5_rd*Uroe**2._rd

Eig(1,3)=1.0_rd
Eig(2,3)=Uroe+Croe
Eig(3,3)=Hroe+Uroe*Croe

Alpha(1)=(0.25_rd*Uroe/Croe)*(RhoR-RhoL)*(2._rd+(gam-1._rd)*Uroe/Croe)-&
        (0.5_rd/Croe)*(1._rd+(gam-1._rd)*Uroe/Croe)*(RhoR*UR-RhoL*UL)+&
        0.5_rd*(gam-1._rd)*(RhoR*ER-RhoL*EL)/(Croe**2._rd)

Alpha(2)=(1._rd-0.5_rd*((Uroe/Croe)**2._rd)*(gam-1._rd))*(RhoR-RhoL)+&
        (gam-1._rd)*Uroe*(RhoR*UR-RhoL*UL)/(Croe**2._rd)-&
        (gam-1._rd)/(Croe**2._rd)*(RhoR*ER-RhoL*EL)

Alpha(3)=-(0.25_rd*Uroe/Croe)*(2._rd-(gam-1._rd)*Uroe/Croe)*(RhoR-RhoL)+&
        (0.5_rd/Croe)*(1._Rd-(gam-1._rd)*Uroe/Croe)*(RhoR*UR-RhoL*UL)+&
        0.5_rd*(gam-1._rd)*(RhoR*ER-RhoL*EL)/(Croe**2._rd)


Dissp(1,Iind)=abs(lambda(1))*Alpha(1)*Eig(1,1)+abs(lambda(2))*Alpha(2)*Eig(1,2)+&
abs(lambda(3))*Alpha(3)*Eig(1,3)
Dissp(2,Iind)=abs(lambda(1))*Alpha(1)*Eig(2,1)+abs(lambda(2))*Alpha(2)*Eig(2,2)+&
abs(lambda(3))*Alpha(3)*Eig(2,3)
Dissp(3,Iind)=abs(lambda(1))*Alpha(1)*Eig(3,1)+abs(lambda(2))*Alpha(2)*Eig(3,2)+&
abs(lambda(3))*Alpha(3)*Eig(3,3)

END SUBROUTINE SuperSonicInflowBC

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!SUBROUTINE 3
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SUBROUTINE SubSonicOutflowBC(Q,Favgin,Dissp,Iind)
USE,INTRINSIC::ISO_FORTRAN_ENV
IMPLICIT NONE
INTEGER,PARAMETER::rd=REAL64
INTEGER,INTENT(IN)::Iind
INTEGER::Jind,k
REAL(KIND=rd),DIMENSION(3,100),INTENT(IN)::Q
REAL(KIND=rd),DIMENSION(3,100),INTENT(INOUT)::Favgin,Dissp
REAL(KIND=rd)::UL,UR,PL,PR,HL,HR,RhoL,RhoR,EL,ER
REAL(KIND=rd)::Rhoroe,Croe,Uroe,Hroe,gam,Pback
REAL(KIND=rd)::Ci,Ti,Mi,Pstag,Mset
REAL(KIND=rd),DIMENSION(3)::Lambda,Alpha
REAL(KIND=rd),DIMENSION(3,3)::Eig


gam=1.4_rd
!!!Defining Roe Variables
!By interface sides, left left, left right etc.
RhoL=Q(1,Iind)
UL=Q(2,Iind)/Q(1,Iind)
UR=Q(2,Iind)/Q(1,Iind)
EL=Q(3,Iind)/Q(1,Iind)

PL=(RhoL*EL-0.5_rd*RhoL*(UL**2._rd))*(gam-1.0_rd)

Ti=gam*PL/RhoL
Ci=sqrt(Ti)
Mi=UL/Ci
Pstag=PL*(1._rd+0.5_rd*(gam-1._rd)*Mi**2)**(gam/(gam-1))
Mset=0.4782_rd
Pback=Pstag*(1._rd+0.5_rd*(gam-1._rd)*Mset**2)**(-gam/(gam-1))
RhoR=(Pback*gam)/Ti

PR=PBack

HL=EL+PL/RhoL
HR=ER+PR/RhoR

!!!Defining Left and Right Fluxes at Both Interfaces
Favgin(1,Iind)=0.5_rd*(RhoR*UR+RhoL*UL)
Favgin(2,Iind)=0.5_rd*(RhoR*(UR**2)+PR+RhoL*(UL**2)+PL)
Favgin(3,Iind)=0.5_rd*(RhoR*UR*HR+RhoL*UL*HL)

!!!Roe Variables At Interface
Rhoroe=sqrt(RhoL*RhoR)
Uroe=(sqrt(RhoL)*UL+sqrt(RhoR)*UR)/(sqrt(RhoL)+sqrt(RhoR))
Hroe=(sqrt(RhoL)*HL+sqrt(RhoR)*HR)/(sqrt(RhoL)+sqrt(RhoR))
Croe=sqrt((gam-1_rd)*(Hroe-0.5_rd*(Uroe**2._rd))) 

!!!Defining eigenvectors
!Eigenvalues
Lambda(1)=Uroe-Croe
Lambda(2)=Uroe
Lambda(3)=Uroe+Croe
!Right Interface
Eig(1,1)=1.0_rd
Eig(2,1)=Uroe-Croe
Eig(3,1)=Hroe-Uroe*Croe 

Eig(1,2)=1.0_rd
Eig(2,2)=Uroe
Eig(3,2)=0.5_rd*Uroe**2._rd

Eig(1,3)=1.0_rd
Eig(2,3)=Uroe+Croe
Eig(3,3)=Hroe+Uroe*Croe

Alpha(1)=(0.25_rd*Uroe/Croe)*(RhoR-RhoL)*(2._rd+(gam-1._rd)*Uroe/Croe)-&
        (0.5_rd/Croe)*(1._rd+(gam-1._rd)*Uroe/Croe)*(RhoR*UR-RhoL*UL)+&
        0.5_rd*(gam-1._rd)*(RhoR*ER-RhoL*EL)/(Croe**2._rd)

Alpha(2)=(1._rd-0.5_rd*((Uroe/Croe)**2._rd)*(gam-1._rd))*(RhoR-RhoL)+&
        (gam-1._rd)*Uroe*(RhoR*UR-RhoL*UL)/(Croe**2._rd)-&
        (gam-1._rd)/(Croe**2._rd)*(RhoR*ER-RhoL*EL)

Alpha(3)=-(0.25_rd*Uroe/Croe)*(2._rd-(gam-1._rd)*Uroe/Croe)*(RhoR-RhoL)+&
        (0.5_rd/Croe)*(1._Rd-(gam-1._rd)*Uroe/Croe)*(RhoR*UR-RhoL*UL)+&
        0.5_rd*(gam-1._rd)*(RhoR*ER-RhoL*EL)/(Croe**2._rd)


Dissp(1,Iind)=abs(lambda(1))*Alpha(1)*Eig(1,1)+abs(lambda(2))*Alpha(2)*Eig(1,2)+&
abs(lambda(3))*Alpha(3)*Eig(1,3)
Dissp(2,Iind)=abs(lambda(1))*Alpha(1)*Eig(2,1)+abs(lambda(2))*Alpha(2)*Eig(2,2)+&
abs(lambda(3))*Alpha(3)*Eig(2,3)
Dissp(3,Iind)=abs(lambda(1))*Alpha(1)*Eig(3,1)+abs(lambda(2))*Alpha(2)*Eig(3,2)+&
abs(lambda(3))*Alpha(3)*Eig(3,3)

END SUBROUTINE SubSonicOutflowBC

!!!
!!!!!!!!! 	END CODE         !!!!!!!!!!!!!!!!!!!!!!!
!!!


