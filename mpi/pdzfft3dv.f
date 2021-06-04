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
C     PARALLEL 3-D REAL-TO-COMPLEX FFT ROUTINE (WITH 2-D DECOMPOSITION)
C
C     FORTRAN77 + MPI SOURCE PROGRAM
C
C     CALL PDZFFT3DV(A,B,NX,NY,NZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,IOPT)
C
C     NX IS THE LENGTH OF THE TRANSFORMS IN THE X-DIRECTION (INTEGER*4)
C     NY IS THE LENGTH OF THE TRANSFORMS IN THE Y-DIRECTION (INTEGER*4)
C     NZ IS THE LENGTH OF THE TRANSFORMS IN THE Z-DIRECTION (INTEGER*4)
C       ------------------------------------
C         NX = (2**IP) * (3**IQ) * (5**IR)
C         NY = (2**JP) * (3**JQ) * (5**JR)
C         NZ = (2**KP) * (3**KQ) * (5**KR)
C       ------------------------------------
C     ICOMMY IS THE COMMUNICATOR IN THE Y-DIRECTION (INTEGER*4)
C     ICOMMZ IS THE COMMUNICATOR IN THE Z-DIRECTION (INTEGER*4)
C     MEY IS THE RANK IN THE Y-DIRECTION (INTEGER*4)
C     NPUY IS THE NUMBER OF PROCESSORS IN THE Y-DIRECTION (INTEGER*4)
C     NPUZ IS THE NUMBER OF PROCESSORS IN THE Z-DIRECTION (INTEGER*4)
C     IOPT = 0 FOR INITIALIZING THE COEFFICIENTS (INTEGER*4)
C     IOPT = -1 FOR FORWARD TRANSFORM WHERE
C              A(NX,NY/NPUY,NZ/NPUZ) IS REAL INPUT VECTOR (REAL*8)
C!HPF$ DISTRIBUTE A(*,BLOCK,BLOCK)
C              A(NX/2+1,NY/NPUY,NZ/NPUZ) IS COMPLEX OUTPUT VECTOR
C                                           (COMPLEX*16)
C!HPF$ DISTRIBUTE A(*,BLOCK,BLOCK)
C              B(NX/2+1,NY/NPUY,NZ/NPUZ) IS WORK VECTOR (COMPLEX*16)
C!HPF$ DISTRIBUTE B(*,BLOCK,BLOCK)
C     IOPT = -2 FOR FORWARD TRANSFORM WHERE
C              A(NX,NY/NPUY,NZ/NPUZ) IS REAL INPUT VECTOR (REAL*8)
C!HPF$ DISTRIBUTE A(*,BLOCK,BLOCK)
C     MEY = 0  A((NX/2)/NPUY+1,NY/NPUZ,NZ) IS COMPLEX OUTPUT VECTOR
C                                             (COMPLEX*16)
C     MEY > 0  A((NX/2)/NPUY,NY/NPUZ,NZ) IS COMPLEX OUTPUT VECTOR
C                                           (COMPLEX*16)
C!HPF$ DISTRIBUTE A(BLOCK,BLOCK,*)
C              B(NX/2+1,NY/NPUY,NZ/NPUZ) IS WORK VECTOR (COMPLEX*16)
C!HPF$ DISTRIBUTE B(*,BLOCK,BLOCK)
C
C     WRITTEN BY DAISUKE TAKAHASHI
C
      SUBROUTINE PDZFFT3DV(A,B,NX,NY,NZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,
     1                     IOPT)
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE 'param.h'
      DIMENSION A(*)
      COMPLEX*16 B(*)
      COMPLEX*16 C(NDA3),D(NDA3)
      COMPLEX*16 WX(NDA3),WY(NDA3),WZ(NDA3)
      DIMENSION LNX(3),LNY(3),LNZ(3)
      SAVE WX,WY,WZ
C
      IF (IOPT .EQ. 0) THEN
        CALL SETTBL(WX,NX)
        CALL SETTBL(WY,NY)
        CALL SETTBL(WZ,NZ)
        RETURN
      END IF
C
      CALL FACTOR(NX,LNX)
      CALL FACTOR(NY,LNY)
      CALL FACTOR(NZ,LNZ)
C
!$OMP PARALLEL PRIVATE(C,D)
      CALL PDZFFT3DV0(A,A,A,A,A,A,A,B,B,B,B,B,B,C,D,WX,WY,WZ,NX,NY,NZ,
     1                LNX,LNY,LNZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,IOPT)
!$OMP END PARALLEL
      RETURN
      END
      SUBROUTINE PDZFFT3DV0(DA,A,AXYZ,AYPZX,AYZX,AYZX2,AZXYP,B,BXYZ,
     1                      BXYZ2,BYZXP,BZPXY,BZXY,C,D,WX,WY,WZ,NX,NY,
     2                      NZ,LNX,LNY,LNZ,ICOMMY,ICOMMZ,MEY,NPUY,NPUZ,
     3                      IOPT)
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE 'mpif.h'
      INCLUDE 'param.h'
      COMPLEX*16 A(*),AXYZ(NX/2+1,NY/NPUY,*),AYPZX(NY/NPUY,NPUY,*),
     1           AYZX(NY,*),AYZX2((NY/NPUY)*(NZ/NPUZ),*),
     2           AZXYP(NZ/NPUZ,*)
      COMPLEX*16 B(*),BXYZ(NX/2+1,NY/NPUY,*),BXYZ2(NX/2+1,*),
     1           BYZXP(NY/NPUY,*),BZPXY(NZ/NPUZ,NPUZ,*),BZXY(NZ,*)
      COMPLEX*16 C(*),D(*)
      COMPLEX*16 WX(*),WY(*),WZ(*)
      DIMENSION DA(NX,NY/NPUY,*)
      DIMENSION ISCNT(MAXNPU),ISDSP(MAXNPU),IRCNT(MAXNPU),IRDSP(MAXNPU)
      DIMENSION LNX(*),LNY(*),LNZ(*)
C
      NNXY=NX/NPUY
      NNYY=NY/NPUY
      NNYZ=NY/NPUZ
      NNZZ=NZ/NPUZ
C
      ISCNT(1)=NNYY*NNZZ*(NNXY/2+1)
      ISDSP(1)=0
      DO 10 I=2,NPUY
        ISCNT(I)=NNYY*NNZZ*(NNXY/2)
        ISDSP(I)=ISDSP(I-1)+ISCNT(I-1)
   10 CONTINUE
      IF (MEY .EQ. 0) THEN
        IRCNT(1)=NNYY*NNZZ*(NNXY/2+1)
        IRDSP(1)=0
        DO 20 I=2,NPUY
          IRCNT(I)=NNYY*NNZZ*(NNXY/2+1)
          IRDSP(I)=IRDSP(I-1)+IRCNT(I-1)
   20   CONTINUE
      ELSE
        IRCNT(1)=NNYY*NNZZ*(NNXY/2)
        IRDSP(1)=0
        DO 30 I=2,NPUY
          IRCNT(I)=NNYY*NNZZ*(NNXY/2)
          IRDSP(I)=IRDSP(I-1)+IRCNT(I-1)
   30   CONTINUE
      END IF
C
      IF (MOD(NNYY,2) .EQ. 0) THEN
!$OMP DO COLLAPSE(2) PRIVATE(I,J)
        DO 70 K=1,NNZZ
          DO 60 J=1,NNYY,2
!DIR$ VECTOR ALIGNED
            DO 40 I=1,NX
              C(I)=DCMPLX(DA(I,J,K),DA(I,J+1,K))
   40       CONTINUE
            CALL FFT235(C,D,WX,NX,LNX)
            BXYZ(1,J,K)=DBLE(C(1))
            BXYZ(1,J+1,K)=DIMAG(C(1))
!DIR$ VECTOR ALIGNED
            DO 50 I=2,NX/2+1
              BXYZ(I,J,K)=0.5D0*(C(I)+DCONJG(C(NX-I+2)))
              BXYZ(I,J+1,K)=(0.0D0,-0.5D0)*(C(I)-DCONJG(C(NX-I+2)))
   50       CONTINUE
   60     CONTINUE
   70   CONTINUE
      ELSE
!$OMP DO COLLAPSE(2) PRIVATE(I,J)
        DO 110 K=1,NNZZ
          DO 100 J=1,NNYY-1,2
!DIR$ VECTOR ALIGNED
            DO 80 I=1,NX
              C(I)=DCMPLX(DA(I,J,K),DA(I,J+1,K))
   80       CONTINUE
            CALL FFT235(C,D,WX,NX,LNX)
            BXYZ(1,J,K)=DBLE(C(1))
            BXYZ(1,J+1,K)=DIMAG(C(1))
!DIR$ VECTOR ALIGNED
            DO 90 I=2,NX/2+1
              BXYZ(I,J,K)=0.5D0*(C(I)+DCONJG(C(NX-I+2)))
              BXYZ(I,J+1,K)=(0.0D0,-0.5D0)*(C(I)-DCONJG(C(NX-I+2)))
   90       CONTINUE
  100     CONTINUE
  110   CONTINUE
!$OMP DO PRIVATE(I)
        DO 140 K=1,NNZZ
!DIR$ VECTOR ALIGNED
          DO 120 I=1,NX
            C(I)=DCMPLX(DA(I,NNYY,K),0.0D0)
  120     CONTINUE
          CALL FFT235(C,D,WX,NX,LNX)
!DIR$ VECTOR ALIGNED
          DO 130 I=1,NX/2+1
            BXYZ(I,NNYY,K)=C(I)
  130     CONTINUE
  140   CONTINUE
      END IF
!$OMP DO COLLAPSE(2) PRIVATE(I,J,JJ)
      DO 180 II=1,NX/2+1,NBLK
        DO 170 JJ=1,NNYY*NNZZ,NBLK
          DO 160 I=II,MIN0(II+NBLK-1,NX/2+1)
!DIR$ VECTOR ALIGNED
            DO 150 J=JJ,MIN0(JJ+NBLK-1,NNYY*NNZZ)
              AYZX2(J,I)=BXYZ2(I,J)
  150       CONTINUE
  160     CONTINUE
  170   CONTINUE
  180 CONTINUE
!$OMP BARRIER
!$OMP MASTER
      CALL MPI_ALLTOALLV(AYZX2,ISCNT,ISDSP,MPI_DOUBLE_COMPLEX,BYZXP,
     1                   IRCNT,IRDSP,MPI_DOUBLE_COMPLEX,ICOMMY,IERR)
!$OMP END MASTER
!$OMP BARRIER
      IF (MEY .EQ. 0) THEN
!$OMP DO PRIVATE(J,L)
        DO 210 K=1,NNZZ*(NNXY/2+1)
          DO 200 L=1,NPUY
!DIR$ VECTOR ALIGNED
            DO 190 J=1,NNYY
              AYPZX(J,L,K)=BYZXP(J,K+(L-1)*NNZZ*(NNXY/2+1))
  190       CONTINUE
  200     CONTINUE
          CALL FFT235(AYZX(1,K),C,WY,NY,LNY)
  210   CONTINUE
!$OMP DO COLLAPSE(2) PRIVATE(J,K,KK)
        DO 250 JJ=1,NY,NBLK
          DO 240 KK=1,NNZZ*(NNXY/2+1),NBLK
            DO 230 J=JJ,MIN0(JJ+NBLK-1,NY)
!DIR$ VECTOR ALIGNED
              DO 220 K=KK,MIN0(KK+NBLK-1,NNZZ*(NNXY/2+1))
                B(K+(J-1)*NNZZ*(NNXY/2+1))=AYZX(J,K)
  220         CONTINUE
  230       CONTINUE
  240     CONTINUE
  250   CONTINUE
      ELSE
!$OMP DO PRIVATE(J,L)
        DO 280 K=1,NNZZ*(NNXY/2)
          DO 270 L=1,NPUY
!DIR$ VECTOR ALIGNED
            DO 260 J=1,NNYY
              AYPZX(J,L,K)=BYZXP(J,K+(L-1)*NNZZ*(NNXY/2))
  260       CONTINUE
  270     CONTINUE
          CALL FFT235(AYZX(1,K),C,WY,NY,LNY)
  280   CONTINUE
!$OMP DO COLLAPSE(2) PRIVATE(J,K,KK)
        DO 320 JJ=1,NY,NBLK
          DO 310 KK=1,NNZZ*(NNXY/2),NBLK
            DO 300 J=JJ,MIN0(JJ+NBLK-1,NY)
!DIR$ VECTOR ALIGNED
              DO 290 K=KK,MIN0(KK+NBLK-1,NNZZ*(NNXY/2))
                B(K+(J-1)*NNZZ*(NNXY/2))=AYZX(J,K)
  290         CONTINUE
  300       CONTINUE
  310     CONTINUE
  320   CONTINUE
      END IF
      IF (MEY .EQ. 0) THEN
!$OMP BARRIER
!$OMP MASTER
        CALL MPI_ALLTOALL(B,NNZZ*(NNXY/2+1)*NNYZ,MPI_DOUBLE_COMPLEX,
     1                    AZXYP,NNZZ*(NNXY/2+1)*NNYZ,MPI_DOUBLE_COMPLEX,
     2                    ICOMMZ,IERR)
!$OMP END MASTER
!$OMP BARRIER
      ELSE
!$OMP BARRIER
!$OMP MASTER
        CALL MPI_ALLTOALL(B,NNZZ*(NNXY/2)*NNYZ,MPI_DOUBLE_COMPLEX,AZXYP,
     1                    NNZZ*(NNXY/2)*NNYZ,MPI_DOUBLE_COMPLEX,ICOMMZ,
     2                    IERR)
!$OMP END MASTER
!$OMP BARRIER
      END IF
      IF (MEY .EQ. 0) THEN
!$OMP DO PRIVATE(K,L)
        DO 350 I=1,(NNXY/2+1)*NNYZ
          DO 340 L=1,NPUZ
!DIR$ VECTOR ALIGNED
            DO 330 K=1,NNZZ
              BZPXY(K,L,I)=AZXYP(K,I+(L-1)*(NNXY/2+1)*NNYZ)
  330       CONTINUE
  340     CONTINUE
          CALL FFT235(BZXY(1,I),C,WZ,NZ,LNZ)
  350   CONTINUE
!$OMP DO COLLAPSE(2) PRIVATE(I,II,K)
        DO 390 KK=1,NZ,NBLK
          DO 380 II=1,(NNXY/2+1)*NNYZ,NBLK
            DO 370 K=KK,MIN0(KK+NBLK-1,NZ)
!DIR$ VECTOR ALIGNED
              DO 360 I=II,MIN0(II+NBLK-1,(NNXY/2+1)*NNYZ)
                A(I+(K-1)*(NNXY/2+1)*NNYZ)=BZXY(K,I)
  360         CONTINUE
  370       CONTINUE
  380     CONTINUE
  390   CONTINUE
      ELSE
!$OMP DO PRIVATE(K,L)
        DO 420 I=1,(NNXY/2)*NNYZ
          DO 410 L=1,NPUZ
!DIR$ VECTOR ALIGNED
            DO 400 K=1,NNZZ
              BZPXY(K,L,I)=AZXYP(K,I+(L-1)*(NNXY/2)*NNYZ)
  400       CONTINUE
  410     CONTINUE
          CALL FFT235(BZXY(1,I),C,WZ,NZ,LNZ)
  420   CONTINUE
!$OMP DO COLLAPSE(2) PRIVATE(I,II,K)
        DO 460 KK=1,NZ,NBLK
          DO 450 II=1,(NNXY/2)*NNYZ,NBLK
            DO 440 K=KK,MIN0(KK+NBLK-1,NZ)
!DIR$ VECTOR ALIGNED
              DO 430 I=II,MIN0(II+NBLK-1,(NNXY/2)*NNYZ)
                A(I+(K-1)*(NNXY/2)*NNYZ)=BZXY(K,I)
  430         CONTINUE
  440       CONTINUE
  450     CONTINUE
  460   CONTINUE
      END IF
      IF (IOPT .EQ. -2) RETURN
      IF (MEY .EQ. 0) THEN
!$OMP BARRIER
!$OMP MASTER
        CALL MPI_ALLTOALL(A,(NNXY/2+1)*NNYZ*NNZZ,MPI_DOUBLE_COMPLEX,B,
     1                    (NNXY/2+1)*NNYZ*NNZZ,MPI_DOUBLE_COMPLEX,
     2                    ICOMMZ,IERR)
!$OMP END MASTER
!$OMP BARRIER
      ELSE
!$OMP BARRIER
!$OMP MASTER
        CALL MPI_ALLTOALL(A,(NNXY/2)*NNYZ*NNZZ,MPI_DOUBLE_COMPLEX,B,
     1                    (NNXY/2)*NNYZ*NNZZ,MPI_DOUBLE_COMPLEX,ICOMMZ,
     2                    IERR)
!$OMP END MASTER
!$OMP BARRIER
      END IF
      IF (MEY .EQ. 0) THEN
!$OMP DO COLLAPSE(2) PRIVATE(I,J,K)
        DO 500 L=1,NPUZ
          DO 490 J=1,NNYZ
            DO 480 K=1,NNZZ
!DIR$ VECTOR ALIGNED
              DO 470 I=1,NNXY/2+1
                A(I+(K-1)*(NNXY/2+1)+(J-1)*(NNXY/2+1)*NNZZ
     1            +(L-1)*(NNXY/2+1)*NNZZ*NNYZ)
     2         =B(I+(J-1)*(NNXY/2+1)+(K-1)*(NNXY/2+1)*NNYZ
     3            +(L-1)*(NNXY/2+1)*NNYZ*NNZZ)
  470         CONTINUE
  480       CONTINUE
  490     CONTINUE
  500   CONTINUE
      ELSE
!$OMP DO COLLAPSE(2) PRIVATE(I,J,K)
        DO 540 L=1,NPUZ
          DO 530 J=1,NNYZ
            DO 520 K=1,NNZZ
!DIR$ VECTOR ALIGNED
              DO 510 I=1,NNXY/2
                A(I+(K-1)*(NNXY/2)+(J-1)*(NNXY/2)*NNZZ
     1            +(L-1)*(NNXY/2)*NNZZ*NNYZ)
     2         =B(I+(J-1)*(NNXY/2)+(K-1)*(NNXY/2)*NNYZ
     3            +(L-1)*(NNXY/2)*NNYZ*NNZZ)
  510         CONTINUE
  520       CONTINUE
  530     CONTINUE
  540   CONTINUE
      END IF
!$OMP BARRIER
!$OMP MASTER
      CALL MPI_ALLTOALLV(A,IRCNT,IRDSP,MPI_DOUBLE_COMPLEX,B,ISCNT,ISDSP,
     1                   MPI_DOUBLE_COMPLEX,ICOMMY,IERR)
!$OMP END MASTER
!$OMP BARRIER
!$OMP DO COLLAPSE(2) PRIVATE(I,J,L)
      DO 590 K=1,NNZZ
        DO 580 J=1,NNYY
!DIR$ VECTOR ALIGNED
          DO 550 I=1,NNXY/2+1
            AXYZ(I,J,K)=B(I+(K-1)*(NNXY/2+1)+(J-1)*(NNXY/2+1)*NNZZ)
  550     CONTINUE
          DO 570 L=2,NPUY
!DIR$ VECTOR ALIGNED
            DO 560 I=1,NNXY/2
              AXYZ(I+(L-1)*(NNXY/2)+1,J,K)
     1       =B(I+(K-1)*(NNXY/2)+(J-1)*(NNXY/2)*NNZZ
     2          +((L-1)*(NNXY/2)+1)*NNZZ*NNYY)
  560       CONTINUE
  570     CONTINUE
  580   CONTINUE
  590 CONTINUE
      RETURN
      END
