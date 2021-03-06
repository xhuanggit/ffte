C
C     (C) COPYRIGHT SOFTWARE, 2000-2004, 2008-2014, ALL RIGHTS RESERVED
C                BY
C         DAISUKE TAKAHASHI
C         FACULTY OF ENGINEERING, INFORMATION AND SYSTEMS
C         UNIVERSITY OF TSUKUBA
C         1-1-1 TENNODAI, TSUKUBA, IBARAKI 305-8573, JAPAN
C         E-MAIL: daisuke@cs.tsukuba.ac.jp
C
C
C     PZFFT1D SPEED TEST PROGRAM
C
C     FORTRAN77 + MPI SOURCE PROGRAM
C
C     WRITTEN BY DAISUKE TAKAHASHI
C
C
C     MODIFIED BY XIAOLONG HUANG, 2021
C
C     ADD INPUT LOOP AND 2TH POWER MIN AND MAX FOR N
C     ADD LOOP SKIP AND AVG, MIN AND MAX TIMING
C     
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE 'mpif.h'
      PARAMETER (NDA=16777216)
      COMPLEX*16 A(NDA),B(NDA),W(NDA)
      DIMENSION IP(3)
      INTEGER*8 N
      INTEGER POW,POW_MIN,POW_MAX,LOOP,LOOP_SKIP,LOOP_ALL
      SAVE A,B,W
C
      CALL MPI_INIT(IERR)
      CALL MPI_COMM_RANK(MPI_COMM_WORLD,ME,IERR)
      CALL MPI_COMM_SIZE(MPI_COMM_WORLD,NPU,IERR)
C
      LOOP_SKIP=1
      IF (ME .EQ. 0) THEN
        WRITE(6,*) ' POW_MIN,POW_MAX,LOOP='
        READ(5,'(3I2)') POW_MIN,POW_MAX,LOOP
        WRITE(6,*) POW_MIN,POW_MAX,LOOP
        WRITE(6,*) ' NPU =',NPU
        WRITE(6,*) ' N,TIME_AVG,TIME_MIN,TIME_MAX,FLOPS='
      END IF
      CALL MPI_BCAST(LOOP,1,MPI_INTEGER,0,MPI_COMM_WORLD,IERR)
      CALL MPI_BCAST(POW_MIN,1,MPI_INTEGER,0,MPI_COMM_WORLD,IERR)
      CALL MPI_BCAST(POW_MAX,1,MPI_INTEGER,0,MPI_COMM_WORLD,IERR)
      LOOP_ALL=LOOP+LOOP_SKIP
C
      DO 20 POW=POW_MIN,POW_MAX
        N=2**REAL(POW)
        CALL FACTOR8(N,IP)
C
        NN=N/NPU
        CALL INIT(A,NN,ME,NPU)
        CALL PZFFT1D(A,B,W,N,MPI_COMM_WORLD,ME,NPU,0)
C
        CALL MPI_BARRIER(MPI_COMM_WORLD,IERR)
        TIME0=0
        DO 10 I=1,LOOP_ALL
          TIME1=MPI_WTIME()
          CALL PZFFT1D(A,B,W,N,MPI_COMM_WORLD,ME,NPU,-1)
          TIME2=MPI_WTIME()
C          
          IF (I .GT. LOOP_SKIP) THEN
            TIME0=TIME0+TIME2-TIME1
          END IF
          CALL MPI_BARRIER(MPI_COMM_WORLD,IERR)
   10   CONTINUE
        TIME0=TIME0/DBLE(LOOP)
        CALL MPI_REDUCE(TIME0,TIME_MIN,1,MPI_REAL8,MPI_MIN,0,
     1           MPI_COMM_WORLD,IERR)
        CALL MPI_REDUCE(TIME0,TIME_MAX,1,MPI_REAL8,MPI_MAX,0,
     1           MPI_COMM_WORLD,IERR)
        CALL MPI_REDUCE(TIME0,TIME_AVG,1,MPI_REAL8,MPI_SUM,0,
     1           MPI_COMM_WORLD,IERR)
        IF (ME .EQ. 0) THEN
          FLOPS=(2.5D0*DBLE(IP(1))+4.66666666666666D0*DBLE(IP(2))
     1           +6.8D0*DBLE(IP(3)))*2.0D0*DBLE(N)/TIME_MAX/1.0D9
          TIME_AVG=TIME_AVG/DBLE(NPU)
          WRITE(6,*) N,TIME_AVG,TIME_MIN,TIME_MAX,FLOPS,' GFLOPS'
        END IF
   20 CONTINUE
C
      CALL MPI_FINALIZE(IERR)
      RETURN
      END
      SUBROUTINE INIT(A,NN,ME,NPU)
      IMPLICIT REAL*8 (A-H,O-Z)
      COMPLEX*16 A(*)
      INTEGER*8 N
C
      N=NN
      N=N*NPU
!$OMP PARALLEL DO
!DIR$ VECTOR ALIGNED
      DO 10 I=1,NN
C        A(I)=DCMPLX(DBLE(I)+DBLE(NN)*DBLE(ME),
C     1              DBLE(N)-(DBLE(I)+DBLE(NN)*DBLE(ME))+1.0D0)
        A(I)=(0.0D0,0.0D0)
   10 CONTINUE
      RETURN
      END
