C
C     FFTE: A FAST FOURIER TRANSFORM PACKAGE
C
C     (C) COPYRIGHT SOFTWARE, 2000-2004, 2008-2014, 2020
C         ALL RIGHTS RESERVED
C                BY
C         DAISUKE TAKAHASHI
C         CENTER FOR COMPUTATIONAL SCIENCES
C         UNIVERSITY OF TSUKUBA
C         1-1-1 TENNODAI, TSUKUBA, IBARAKI 305-8577, JAPAN
C         E-MAIL: daisuke@cs.tsukuba.ac.jp
C
C
C     PDZFFT3DV AND PZFFT3DV TEST PROGRAM
C
C     FORTRAN77 + MPI SOURCE PROGRAM
C
C     WRITTEN BY DAISUKE TAKAHASHI
C
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE 'mpif.h'
      PARAMETER (NDA=16777216)
      COMPLEX*16 A(NDA),B(NDA)
      DIMENSION LNPU(3)
      SAVE A,B
C
      CALL MPI_INIT(IERR)
      CALL MPI_COMM_RANK(MPI_COMM_WORLD,ME,IERR)
      CALL MPI_COMM_SIZE(MPI_COMM_WORLD,NPU,IERR)
C
      CALL FACTOR(NPU,LNPU)
      NPUZ=(2**(LNPU(1)/2))*(3**(LNPU(2)/2))*(5**(LNPU(3)/2))
      NPUY=NPU/NPUZ
C
      CALL MPI_COMM_SPLIT(MPI_COMM_WORLD,ME/NPUY,0,ICOMMY,IERR)
      CALL MPI_COMM_SPLIT(MPI_COMM_WORLD,MOD(ME,NPUY),0,ICOMMZ,IERR)
      CALL MPI_COMM_RANK(ICOMMY,MEY,IERR)
C
      IF (ME .EQ. 0) THEN
        WRITE(6,*) ' NX,NY,NZ ='
        READ(5,*) NX,NY,NZ
      END IF
      CALL MPI_BCAST(NX,1,MPI_INTEGER,0,MPI_COMM_WORLD,IERR)
      CALL MPI_BCAST(NY,1,MPI_INTEGER,0,MPI_COMM_WORLD,IERR)
      CALL MPI_BCAST(NZ,1,MPI_INTEGER,0,MPI_COMM_WORLD,IERR)
C
      NN=NX*(NY/NPUY)*(NZ/NPUZ)
      CALL INIT(A,NN,ME,NPU)
      CALL PDZFFT3DV(A,B,NX,NY,NZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,0)
      CALL PDZFFT3DV(A,B,NX,NY,NZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,-1)
      CALL DUMP(A,(NX/2+1)*(NY/NPUY)*(NZ/NPUZ),ME,NPU)
C
      CALL PZDFFT3DV(A,B,NX,NY,NZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,0)
      CALL PZDFFT3DV(A,B,NX,NY,NZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,1)
      CALL RDUMP(A,NN,ME,NPU)
C
      CALL MPI_COMM_FREE(ICOMMY,IERR)
      CALL MPI_COMM_FREE(ICOMMZ,IERR)
      CALL MPI_FINALIZE(IERR)
      STOP
      END
      SUBROUTINE INIT(A,NN,ME,NPU)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION A(*)
      INTEGER*8 N
C
      N=NN
      N=N*NPU
!$OMP PARALLEL DO
!DIR$ VECTOR ALIGNED
      DO 10 I=1,NN
        A(I)=DBLE(I)+DBLE(NN)*DBLE(ME)
   10 CONTINUE
      RETURN
      END
      SUBROUTINE DUMP(A,NN,ME,NPU)
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE 'mpif.h'
      COMPLEX*16 A(*)
C
      DO 20 J=0,NPU-1
        CALL MPI_BARRIER(MPI_COMM_WORLD,IERR)
        IF (J .EQ. ME) THEN
          DO 10 I=1,NN
            WRITE(6,*) ' ME=',ME,A(I)
   10     CONTINUE
        END IF
   20 CONTINUE
      RETURN
      END
      SUBROUTINE RDUMP(A,NN,ME,NPU)
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE 'mpif.h'
      DIMENSION A(*)
C
      DO 20 J=0,NPU-1
        CALL MPI_BARRIER(MPI_COMM_WORLD,IERR)
        IF (J .EQ. ME) THEN
          DO 10 I=1,NN
            WRITE(6,*) ' ME=',ME,A(I)
   10     CONTINUE
        END IF
   20 CONTINUE
      RETURN
      END
