! =====================================================
subroutine rpn2(ixy,maxm,meqn,mwaves,maux,mbc,mx,ql,qr,auxl,auxr,wave,s,amdq,apdq)
! =====================================================

! Roe-solver for the 2D shallow water equations
! solve Riemann problems along one slice of data.

! waves: 3
! equations: 3

! Conserved quantities:
!       1 depth
!       2 x_momentum
!       3 y_momentum

! On input, ql contains the state vector at the left edge of each cell
!           qr contains the state vector at the right edge of each cell

! This data is along a slice in the x-direction if ixy=1
!                            or the y-direction if ixy=2.

! On output, wave contains the waves, s the speeds,
! and amdq, apdq the decomposition of the flux difference
!   f(qr(i-1)) - f(ql(i))
! into leftgoing and rightgoing parts respectively.
! With the Roe solver we have
!    amdq  =  A^- \Delta q    and    apdq  =  A^+ \Delta q
! where A is the Roe matrix.  An entropy fix can also be incorporated
! into the flux differences.

! Note that the i'th Riemann problem has left state qr(:,i-1)
!                                    and right state ql(:,i)
! From the basic clawpack routines, this routine is called with ql = qr


! This Riemann solver differs from the original clawpack Riemann solver
! for the interleaved indices

    implicit double precision (a-h,o-z)

    dimension   ql(meqn,           1-mbc:maxm+mbc)
    dimension   qr(meqn,           1-mbc:maxm+mbc)
    dimension    s(mwaves,         1-mbc:maxm+mbc)
    dimension wave(meqn,   mwaves, 1-mbc:maxm+mbc)
    dimension  apdq(meqn,          1-mbc:maxm+mbc)
    dimension  amdq(meqn,          1-mbc:maxm+mbc)

!   # Gravity constant set in the shallow1D.py or setprob.f90 file
    common /cparam/ grav

!   # Roe averages quantities of each interface
    parameter (maxm2 = 1800)
    double precision u(-6:maxm2+7),v(-6:maxm2+7),a(-6:maxm2+7), &
                     h(-6:maxm2+7)


!   local arrays
!   ------------
    dimension delta(3)
    logical :: efix

    data efix /.false./    !# Use entropy fix for transonic rarefactions

!   # Set mu to point to  the component of the system that corresponds
!   # to momentum in the direction of this slice, mv to the orthogonal
!   # momentum:

    if (ixy == 1) then
        mu = 2
        mv = 3
    else
        mu = 3
        mv = 2
    endif


!   # Note that notation for u and v reflects assumption that the
!   # Riemann problems are in the x-direction with u in the normal
!   # direciton and v in the orthogonal direcion, but with the above
!   # definitions of mu and mv the routine also works with ixy=2
!   # and returns, for example, f0 as the Godunov flux g0 for the
!   # Riemann problems u_t + g(u)_y = 0 in the y-direction.


!   # Compute the Roe-averaged variables needed in the Roe solver.

    do 10 i = 2-mbc, mx+mbc
        h(i) = (qr(1,i-1)+ql(1,i))*0.50d0
        hsqrtl = dsqrt(qr(1,i-1))
        hsqrtr = dsqrt(ql(1,i))
        hsq2 = hsqrtl + hsqrtr
        u(i) = (qr(mu,i-1)/hsqrtl + ql(mu,i)/hsqrtr) / hsq2
        v(i) = (qr(mv,i-1)/hsqrtl + ql(mv,i)/hsqrtr) / hsq2
        a(i) = dsqrt(grav*h(i))
    10 END DO


!   # now split the jump in q at each interface into waves

!   # find a1 thru a3, the coefficients of the 3 eigenvectors:
    do 20 i = 2-mbc, mx+mbc
        delta(1) = ql(1,i) - qr(1,i-1)
        delta(2) = ql(mu,i) - qr(mu,i-1)
        delta(3) = ql(mv,i) - qr(mv,i-1)
        a1 = ((u(i)+a(i))*delta(1) - delta(2))*(0.50d0/a(i))
        a2 = -v(i)*delta(1) + delta(3)
        a3 = (-(u(i)-a(i))*delta(1) + delta(2))*(0.50d0/a(i))
    
!      # Compute the waves.
    
        wave(1,1,i) = a1
        wave(mu,1,i) = a1*(u(i)-a(i))
        wave(mv,1,i) = a1*v(i)
        s(1,i) = u(i)-a(i)
    
        wave(1,2,i) = 0.0d0
        wave(mu,2,i) = 0.0d0
        wave(mv,2,i) = a2
        s(2,i) = u(i)
    
        wave(1,3,i) = a3
        wave(mu,3,i) = a3*(u(i)+a(i))
        wave(mv,3,i) = a3*v(i)
        s(3,i) = u(i)+a(i)
    20 END DO


!    # compute flux differences amdq and apdq.
!    ---------------------------------------

!     # no entropy fix
!     ----------------

!     # amdq = SUM s*wave   over left-going waves
!     # apdq = SUM s*wave   over right-going waves

    do 100 m=1,3
        do 100 i=2-mbc, mx+mbc
            amdq(m,i) = 0.d0
            apdq(m,i) = 0.d0
            do 90 mw=1,mwaves
                if (s(mw,i) < 0.d0) then
                    amdq(m,i) = amdq(m,i) + s(mw,i)*wave(m,mw,i)
                else
                    apdq(m,i) = apdq(m,i) + s(mw,i)*wave(m,mw,i)
                endif
            90 END DO
    100 END DO
    return
    end subroutine rpn2


