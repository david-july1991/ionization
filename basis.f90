module basis
    use kind_type 
    use global 
    implicit none
    real(dp), save, allocatable, protected :: H1(:, :), E1(:), E(:)
    real(dp), save, pointer,     protected :: H(:, :, :)
contains


! ==================================================
! FUNCTION
! ==================================================
! kinetic term -------------------------------------
function term_kinet(i, j)
    use hamiltonian, only: delta_rho, dr_p_drho
    integer(i4), intent(in) :: i, j 
    real   (dp) :: term_kinet
    term_kinet = -delta_rho(i, j)/dr_p_drho**2.d0 &
                    /(2.d0*Mass)
end function term_kinet 
! potential term -----------------------------------
function term_poten(i)
    use hamiltonian, only: coord_r, poten_r 
    integer(i4), intent(in) :: i
    real   (dp) :: term_poten
    term_poten = poten_r(coord_r(i)) & 
                    *Charge
end function term_poten 
! angular term -------------------------------------
function term_angular(i, l)  
    use hamiltonian, only: coord_r
    integer(i4), intent(in) :: i, l 
    real   (dp) :: term_angular
    term_angular = dble(l)*(dble(l) +1.d0)/coord_r(i)**2.d0 & 
                    /(2.d0*Mass)
end function term_angular
! floquet term -------------------------------------
function term_floquet(n)
    use hamiltonian, only: coord_r
    integer(i4), intent(in) :: n
    real   (dp) :: term_floquet
    term_floquet = -dble(n)*Freq
end function term_floquet
! dipole term --------------------------------------
function term_dipole(i)
    use hamiltonian, only: coord_r
    integer(i4), intent(in) :: i
    real   (dp) :: term_dipole
    term_dipole = 0.5d0*Amp*coord_r(i) & 
                    *Charge
end function term_dipole
! end funciton -------------------------------------










! ==================================================
! SUB-CALCULATE
! ==================================================
! single hamiltonian -------------------------------
subroutine SUB_single(l)
    use linear, only: diag_sym 
    integer(i4), intent(in) :: l 
    integer(i4) :: i, j 
    H1(:, :) = 0.d0 
    E1(:) = 0.d0 
    do j = 1, N 
!         do i = 1, N 
        do i = 1, j 
            H1(i, j) = term_kinet(i, j)
        end do 
        i = j 
            H1(i, j) = H1(i, j) +term_poten(i) +term_angular(i, l)
    end do 
    call diag_sym(H1(:, :), E1(:))
end subroutine SUB_single
! end single hamiltonian ---------------------------
! floquet hamiltonian ------------------------------
subroutine SUB_floquet(l)
    use linear, only: diag_sym
    integer(i4), intent(in) :: l 
    real(dp), pointer :: H_p1(:, :, :, :), H_p2(:, :), H_p3(:)
    integer(i4) :: i1, i2, j1, j2 

    nullify(H_p1)
    nullify(H_p2)
    nullify(H_p3)
    allocate(H_p1(1:N, -F:F, 1:N, -F:F))
    allocate(H_p2(1:N*(2*F +1), 1:N*(2*F +1)))
    allocate(H_p3(1:N*(2*F +1)*N*(2*F +1)))
    H   (1:N, -F:F, 1:N*(2*F +1))    => H_p3(1:N*(2*F +1)*N*(2*F +1))
    H_p1(1:N, -F:F, 1:N, -F:F)       => H_p3(1:N*(2*F +1)*N*(2*F +1))
    H_p2(1:N*(2*F +1), 1:N*(2*F +1)) => H_p3(1:N*(2*F +1)*N*(2*F +1))

    H_p1(:, :, :, :) = 0.d0 
    do j2 = -F, F 
        do j1 = 1, N 
            i2 = j2 
                do i1 = 1, j1 
                    H_p1(i1, i2, j1, j2) = term_kinet(i1, j1)
                end do 
                i1 = j1 
                    H_p1(i1, i2, j1, j2) = H_p1(i1, i2, j1, j2) &
                        +term_poten(i1) +term_angular(i1, l) +term_floquet(i2)
            if(.not. j2 == -F) i2 = j2 -1 
                i1 = j1 
                    H_p1(i1, i2, j1, j2) = H_p1(i1, i2, j1, j2) &
                        +term_dipole(i1)
        end do 
    end do 
    call diag_sym(H_p2, E)

    nullify(H_p1)
    nullify(H_p2)
    nullify(H_p3)
end subroutine SUB_floquet
! end floquet hamiltonian --------------------------
! descale single wave function ---------------------
subroutine SUB_descale_H1
    use hamiltonian, only: coord_weight, dr_p_drho
    integer(i4) :: i0, i, j 
    i0 = 1 
    if(size(H1(:, 1)) == 1) i0 = N 
    do j = 1, N 
        do i = i0, N 
            H1(i, j) = H1(i, j) &
                        /(coord_weight(i)*dr_p_drho)**0.5_dp
        end do 
    end do 
end subroutine SUB_descale_H1
! end descale single wave function -----------------
! descale floquet wave function --------------------
subroutine SUB_descale_H
    use hamiltonian, only: coord_weight, dr_p_drho
    integer(i4) :: i0, i1, i2, j 
    i0 = 1 
    if(size(H(:, 0, 1)) == 1) i0 = N 
    do j = 1, N*(2*F +1)
        do i2 = -F, F 
            do i1 = i0, N 
                H(i1, i2, j) = H(i1, i2, j) &
                                    /(coord_weight(i1)*dr_p_drho)**0.5_dp
            end do 
        end do 
    end do 
end subroutine SUB_descale_H
! end descale floquet wave function ----------------










! ==================================================
! PROCESS
! ==================================================
! hamiltonian --------------------------------------
subroutine PROC_H(l) 
    character(30), parameter :: form_out1 = '(1A15, 5F9.3)'
    character(60), parameter :: form_out2 = '(1A15, 1ES15.3, 1ES15.3)'
    integer(i4), intent(in) :: l 

!     if(allocated(H1)) deallocate(H1)
!     if(allocated(E1)) deallocate(E1)
!     allocate(H1(1:N, 1:N))
!     allocate(E1(1:N))
!     call SUB_single(l)
!     write(file_log, form_out1) "Energy: ", (E1(i), i = 1, 5) 

    nullify(H)
    if(allocated(E))  deallocate(E)
    allocate(H(1:N, -F:F, 1:N*(2*F +1)))
    allocate(E(1:N*(2*F +1)))
    call SUB_floquet(l)
    write(file_log, form_out2) "Dressed E: ", minval(E(:)), maxval(E(:))

!     if(.not. allocated(H)) then 
!         if(op_mat_f == 1) then 
!             allocate(H(1:N*(2*F +1), -F:F, 1:N))
!         else if(op_mat_f == 0) then 
!             allocate(H(1:N*(2*F +1), -F:F, N:N))
!         end if 
!     end if 
!     call SUB_descale_H1
    call SUB_descale_H

!     if(allocated(H1)) deallocate(H1)
!     if(allocated(E1)) deallocate(E1)
!     if(allocated(E))  deallocate(E)
!     nullify(H)
end subroutine PROC_H
! end hamiltonian ----------------------------------
! basis plot ---------------------------------------
subroutine PROC_basis_plot(l)
    use hamiltonian, only: coord_r
    integer  (i1), parameter  :: file_psi = 101, file_ene = 102
    character(30), parameter  :: & 
        form_gen = '(2X, 25ES25.10)', & 
        form_tit = '("# ", 1A75)', &
        form_sub = '("# ", 2A25, 1A50)', &
        form_lin = '("# ", 2A25, 20ES25.10)'
    integer  (i4), intent(in) :: l 
    integer  (i4) :: i1, i2, j
    character (3) :: ch 

    write(ch, '(I3.3)') l 

!         open(file_psi, file = "output/basis_u_"//ch//".d")
!         open(file_ene, file = "output/basis_energy_"//ch//".d")
!         write(file_psi, form_tit) "==========================================================================="
!         write(file_psi, form_tit) "BASIS FUNCTION OF INNER REIGON IN THE ABSENCE OF THE FIELD"
!         write(file_psi, form_tit) "==========================================================================="  
!         write(file_psi, form_sub) "", " RADIAL COORDINATE ", " WAVE FUNCTION PER R (ENERGY) "
!         write(file_psi, form_lin) " ----------------------- ", " ----------------------- ", &
!                                     (E1(j), j = 1, 10), (E1(j), j = N -9, N)
!         write(file_psi, *)
!         write(file_psi, form_gen) 0.d0, 0.d0, (0.d0, j = 1, 20)
!         do i1 = 1, N 
!             write(file_psi, form_gen) 0.d0, coord_r(i1), & 
!                 (H1(i1, j), j = 1, 10), (H1(i1, j), j = N -9, N)
!         end do 
!         write(file_ene, form_tit) "==========================================================================="
!         write(file_ene, form_tit) "ENERGY LEVEL OF INNER REGION IN THE ABSENCE OF THE FIELD"
!         write(file_ene, form_tit) "==========================================================================="
!         write(file_ene, form_sub) " STATE NUMBER ", " ENERGY "
!         write(file_ene, form_sub) " ----------------------- ", " ----------------------- "
!         write(file_ene, *)
!         do j = 1, N 
!             write(file_ene, form_gen) dble(j), E(j)
!         end do 
!         close(file_psi)
!         close(file_ene)

    if(.not. F == 0) then 
        open(file_psi, file = "output/dressed_u_"//ch//".d")
        open(file_ene, file = "output/dressed_energy_"//ch//".d")
        write(file_psi, form_tit) "==========================================================================="
        write(file_psi, form_tit) "DRESSED BASIS FUNCTION OF INNER REIGON"
        write(file_psi, form_tit) "==========================================================================="  
        write(file_psi, form_sub) " PHOTON SPACE ", " RADIAL COORDINATE ", " WAVE FUNCTION PER R (ENERGY) "
        write(file_psi, form_lin) " ----------------------- ", " ----------------------- ", &
                                    (E(j), j = 1, 10), (E(j), j = N -9, N)
        write(file_psi, *)
        do i2 = -F, F 
            write(file_psi, form_gen) dble(i2), 0.d0, (0.d0, j = 1, 20)
            do i1 = 1, N 
                write(file_psi, form_gen) dble(i2), coord_r(i1), & 
                    (H(i1, i2, j), j = 1, 10), (H(i1, i2, j), j = N -9, N)
            end do 
            write(file_psi, *)
        end do 
        write(file_ene, form_tit) "==========================================================================="
        write(file_ene, form_tit) "DRESSED ENERGY LEVEL OF INNER REGION"
        write(file_ene, form_tit) "==========================================================================="
        write(file_ene, form_sub) " STATE NUMBER ", " ENERGY "
        write(file_ene, form_sub) " ----------------------- ", " ----------------------- "
        write(file_ene, *)
        do j = 1, (2*F +1)*N 
            write(file_ene, form_gen) dble(j), E(j)
        end do 
        close(file_psi)
        close(file_ene)
    end if 
end subroutine PROC_basis_plot
! end basis plot -----------------------------------
! break --------------------------------------------
subroutine PROC_basis_break
!     if(allocated(H1)) deallocate(H1)
!     if(allocated(E1)) deallocate(E1)
!     if(op_mat_h == 0) nullify(H)
!     if(op_mat_e == 0 .and. allocated(E)) deallocate(E)
end subroutine PROC_basis_break
! end break ----------------------------------------
! out ----------------------------------------------
subroutine PROC_basis_out
    if(allocated(H1)) deallocate(H1)
    if(allocated(E1)) deallocate(E1)
    if(allocated(E))  deallocate(E)
    nullify(H)
end subroutine PROC_basis_out
! end out ------------------------------------------
end module basis
