# Common routines used by ADI ADSP-SC58x and ADSP-SC57x boards and ADSP-SC59x SOM
#
# Copyright (c) 2015-2020 Analog Devices, Inc. All Rights Reserved.
# This software is proprietary to Analog Devices, Inc. and its licensors.

proc smpu_config { smpu } {
   # Use SMPU instances to disable accesses to system memory that may not be
   # populated or needs to be initialized before being accessed. This will
   # avoid the possibility of an infinite stall in the system due to a
   # speculative access to a disabled or uninitialized memory. This is also
   # part of the workaround for silicon anomaly 20000018.

   if { $smpu == 0 } {
      set smpu_baseaddr 0x31007000
   } elseif { $smpu == 8 } {
      set smpu_baseaddr 0x31099000
   } elseif { $smpu == 9 } {
      set smpu_baseaddr 0x310a0000
   } elseif { $smpu == 10 } {
      set smpu_baseaddr 0x310a1000
   } else {
      puts stderr "Error: unknown SMPU number"
      shutdown error
   }

   set smpu_ctl			[expr {$smpu_baseaddr + 0x0}]
   set smpu_securectl	[expr {$smpu_baseaddr + 0x800}]

   # SMC - SMPU instance 0
   # *pREG_SMPU0_CTL |= ENUM_SMPU_CTL_RSDIS;
   pmmw $smpu_ctl 0x1 0

   # *pREG_SMPU0_SECURECTL = 0xf01;
   mww phys $smpu_securectl 0xf01
}

proc canfd_config { canfd_base } {

   set canfd_cfg $canfd_base
   set canfd_rx_mb_gmsk   [expr {$canfd_cfg + 0x10}]
   set canfd_rx_14_msk    [expr {$canfd_cfg + 0x14}]
   set canfd_rx_15_msk    [expr {$canfd_cfg + 0x18}]
   set canfd_rx_fifo_gmsk [expr {$canfd_cfg + 0x48}]
   set canfd_ram          [expr {$canfd_cfg + 0x80}]
   set canfd_rx_imsk0     [expr {$canfd_cfg + 0x880}]

   # /* Set the Freeze and Halt bit to enter freeze mode. */
   # pCANFDRegs->CFG |= BITM_CANFD_CFG_FRZ;
   # pCANFDRegs->CFG |= BITM_CANFD_CFG_HALT;
   pmmw $canfd_cfg 0x40000000 0x0
   pmmw $canfd_cfg 0x10000000 0x0

   # /* Wait for the Freeze acknowledgment. */
   # while((pCANFDRegs->CFG & BITM_CANFD_CFG_FRZACK) == 0u) { }
   set data [pmemread32 $canfd_cfg]
   while { ![expr {$data & 0x1000000}] } {
      set data [pmemread32 $canfd_cfg]
   }

   # /* Initialize the RAM area occupied by message buffers. */
   # for (i=0u; i<(RAM_SIZE/sizeof(uint32_t)); i++)
   # ram[i] = 0x0u;
   for {set i 0} {$i < 256} {incr i} {
      mww phys [expr {$canfd_ram + ($i * 4)}] 0x0
   }

   # /* Initialize the RAM area occupied by some of the CAN registers. */
   # pCANFDRegs->RX_MB_GMSK = 0xFFFFFFFFu;
   # pCANFDRegs->RX_14_MSK = 0xFFFFFFFFu;
   # pCANFDRegs->RX_15_MSK = 0xFFFFFFFFu;
   # pCANFDRegs->RX_FIFO_GMSK = 0xFFFFFFFFu;
   mww phys $canfd_rx_mb_gmsk   0xffffffff
   mww phys $canfd_rx_14_msk    0xffffffff
   mww phys $canfd_rx_15_msk    0xffffffff
   mww phys $canfd_rx_fifo_gmsk 0xffffffff

   # /* Initialize the IMSK registers which occupy RAM. */
   # for (i=0u;
   # i<(sizeof(pCANFDRegs->RX_IMSK)/sizeof(pCANFDRegs->RX_IMSK[0]));
   # i++)
   # pCANFDRegs->RX_IMSK[i] = 0u;
   for {set i 0} {$i < 64} {incr i} {
      mww phys [expr {$canfd_rx_imsk0 + ($i * 4)}] 0x0
   }

   # /* Clear the Freeze and Halt bit to exit the freeze mode. */
   # pCANFDRegs->CFG &= ~(BITM_CANFD_CFG_FRZ|BITM_CANFD_CFG_HALT);
   pmmw $canfd_cfg 0x0 0x50000000

   # /* Wait for the Freeze acknowledgment to clear. */
   # while(pCANFDRegs->CFG & BITM_CANFD_CFG_FRZACK) { }
   set data [pmemread32 $canfd_cfg]
   while { [expr {$data & 0x1000000}] } {
      set data [pmemread32 $canfd_cfg]
   }
}

proc adspsc5xx_init_ddr3 { dmc } {
   global CHIPNAME

   if { $dmc == 0 } {
      set dmc_baseaddr 0x31070000
      set dummy_addr 0x80000000
   } else {
      set dmc_baseaddr 0x31073000
      set dummy_addr 0xc0000000
   }

   set dmc_ctl			[expr {$dmc_baseaddr + 0x4}]
   set dmc_stat			[expr {$dmc_baseaddr + 0x8}]
   set dmc_cfg			[expr {$dmc_baseaddr + 0x40}]
   set dmc_tr0			[expr {$dmc_baseaddr + 0x44}]
   set dmc_tr1			[expr {$dmc_baseaddr + 0x48}]
   set dmc_tr2			[expr {$dmc_baseaddr + 0x4c}]
   set dmc_mr			[expr {$dmc_baseaddr + 0x60}]
   set dmc_mr1			[expr {$dmc_baseaddr + 0x64}]
   set dmc_mr2			[expr {$dmc_baseaddr + 0x68}]
   set dmc_dllctl		[expr {$dmc_baseaddr + 0x80}]
   set dmc_cphy_ctl		[expr {$dmc_baseaddr + 0x1c0}]
   set dmc_phy_ctl0		[expr {$dmc_baseaddr + 0x1000}]
   set dmc_phy_ctl1		[expr {$dmc_baseaddr + 0x1004}]
   set dmc_phy_ctl2		[expr {$dmc_baseaddr + 0x1008}]
   set dmc_phy_ctl3		[expr {$dmc_baseaddr + 0x100c}]
   set dmc_phy_ctl4		[expr {$dmc_baseaddr + 0x1010}]
   set dmc_cal_padctl0	[expr {$dmc_baseaddr + 0x1034}]
   set dmc_cal_padctl2	[expr {$dmc_baseaddr + 0x103c}]

   # Configure SMPU (silicon anomaly 20000018)
   if { $CHIPNAME == "adspsc589" } {
      smpu_config 0
      smpu_config 8
   } elseif { $CHIPNAME == "adspsc573" } {
      smpu_config 0
   }

   # Set the RESETDLL bit (bit 11 of the DMC_PHY_CTL0 register) before CGU Initialization.
   # *pREG_DMC0_PHY_CTL0 |= BITM_DMC_PHY_CTL0_RESETDLL;
   pmmw $dmc_phy_ctl0 0x800 0

   # Set CGU clock select register to CLKO2/4 (ARM core)
   mww phys 0x3108d010 4

   # Reset processor to default power settings
   # Clear DISABLE and set EXIT_ACTIVE in CGU0_PLLCTL
   mww phys 0x3108d004 0x2
   # Set DF = 0 MSEL = 0x12 in CGU0_CTL
   mww phys 0x3108d000 0x1200
   # Set SYSSEL = 2 S0SEL = 2 S1SEL = 2 CSEL = 1 DSEL = 1 in CGU0_DIV
   mww phys 0x3108d00c 0x44014241

   # Read CGU0_STAT to make sure it's in FULL ON mode
   #mdw phys 0x3108d008

   # Clear the PHY_CTL0 after CGU Initialization
   mww phys $dmc_phy_ctl0 0

   # Wait for DLL lock - 9000 DCLK cycles
   # 1ms should be enough
   after 1

   # For DDR3 mode, set bit 1 and configure bits [5:2] of the DMC_CPHY_CTL
   # registers with WL(Write Latency) where WL is defined as CWL(CAS Write
   # Latency) + AL(Additive Latency) in DCLK cycles. Here WL = 6 as CWL
   # is 6 and AL is 0.
   #
   # When DMC_CPHY_CTL registers are written on the ADSP-SC57x/SC58x ARM
   # core 0 a false data abort exception is triggered that can only be
   # avoided by ensuring that asynchronous aborts are disabled by the A
   # bit in the Program State Registers (CSPR) being set. Versions of the
   # CCES uCOSII addin prior to 2.8.0 require an update in OSTaskStkInit
   # to avoid this problem.
   #
   # Writes to DMC_CPHY_CTL registers on the SHARC cores will also trigger an
   # INTR_SYS_C1_DATA_WRITE_ERR SEC error event. This can be cleared by
   # the SHARC before the ARM core enables asynchronous aborts, should it be
   # necessary to have asynchronous aborts enabled for the ARM.
   #
   # For additional information on this behavior refer to anomaly 20000091.

   # *pREG_DMC0_CPHY_CTL = 0x0000001A
   # Because of a processor anomaly, writing REG_DMC_CPHY_CTL through memory ap
   # will cause a DP error. So we have to write it through the core, i.e. without
   # the 'phys' flag. But writing it through the core will still cause a data
   # abort, although the write does go through fine. Thus we need to add the
   # new flag "ignore-data-abort" to ignore this data abort. Otherwise, the
   # commands after this command will not be run.
   mww ignore-data-abort $dmc_cphy_ctl 0x1a

   # *pREG_DMC0_PHY_CTL0 |= 0x0000000F;
   pmmw $dmc_phy_ctl0 0xf 0
   # *pREG_DMC0_PHY_CTL2 |= 0xFC000000;
   pmmw $dmc_phy_ctl2 0xfc000000 0
   # *pREG_DMC0_PHY_CTL3 |= 0x0A0000C0;
   pmmw $dmc_phy_ctl3 0xa0000c0 0

   # *pREG_DMC0_PHY_CTL1 = 0x00000000;
   mww phys $dmc_phy_ctl1 0

   # *pREG_DMC0_PHY_CTL4 = 0x00000000;
   mww phys $dmc_phy_ctl4 0

   # Program the PAD RTT and driver impedance values required here
   # *pREG_DMC0_CAL_PADCTL0 = 0xE0000000;
   mww phys $dmc_cal_padctl0 0xe0000000
   if { $CHIPNAME == "adspsc589" } {
      # *pREG_DMC0_CAL_PADCTL2 = 0x0078283C;
      mww phys $dmc_cal_padctl2 0x0078283c
   } elseif { $CHIPNAME == "adspsc573" } {
      # *pREG_DMC0_CAL_PADCTL2 = 0x00783C3C;
      mww phys $dmc_cal_padctl2 0x00783c3c
   }

   # Start calibration
   # *pREG_DMC0_CAL_PADCTL0 |= 0x10000000;
   pmmw $dmc_cal_padctl0 0x10000000 0

   # Wait for PAD calibration to complete - 300 DCLK cycle.
   # 1ms should be enough
   after 1

   # *pREG_DMC0_CFG = 0x00000522;
   mww phys $dmc_cfg 0x00000522
   # *pREG_DMC0_TR0 = 0x41711646;
   mww phys $dmc_tr0 0x41711646
   # *pREG_DMC0_TR1 = 0x40480db6;
   mww phys $dmc_tr1 0x40480db6
   # *pREG_DMC0_TR2 = 0x00347417;
   mww phys $dmc_tr2 0x00347417
   # *pREG_DMC0_MR = 0x00000730;
   mww phys $dmc_mr 0x00000730
   # *pREG_DMC0_MR1 = 0x00000006;
   mww phys $dmc_mr1 0x00000006
   # *pREG_DMC0_MR2 = 0x00000008;
   mww phys $dmc_mr2 0x00000008
   # *pREG_DMC0_CTL = 0x00000405;
   mww phys $dmc_ctl 0x00000405

   # Wait till INITDONE is set
   # while((*pREG_DMC0_STAT&BITM_DMC_STAT_INITDONE)==0);
   set data 0
   while { [expr {$data & 4}] == 0 } {
      set data [pmemread32 $dmc_stat]
   }

   # *pREG_DMC0_DLLCTL = 0x00000948;
   mww phys $dmc_dllctl 0x00000948

   # Workaround for silicon anomaly 20000037
   # Dummy read
   set data [memread32 $dummy_addr]
   # *pREG_DMC0_PHY_CTL0|=0x1000;
   # *pREG_DMC0_PHY_CTL0&=~0x1000;
   set data [pmemread32 $dmc_phy_ctl0]
   mww phys $dmc_phy_ctl0 [expr {$data | 0x1000}]
   mww phys $dmc_phy_ctl0 [expr {$data & ~0x1000}]
}

proc adspsc5xx_init_ddr2 { } {
   set dmc_baseaddr 0x31070000
   set dummy_addr 0x80000000

   set dmc_ctl			[expr {$dmc_baseaddr + 0x4}]
   set dmc_stat			[expr {$dmc_baseaddr + 0x8}]
   set dmc_cfg			[expr {$dmc_baseaddr + 0x40}]
   set dmc_tr0			[expr {$dmc_baseaddr + 0x44}]
   set dmc_tr1			[expr {$dmc_baseaddr + 0x48}]
   set dmc_tr2			[expr {$dmc_baseaddr + 0x4c}]
   set dmc_mr			[expr {$dmc_baseaddr + 0x60}]
   set dmc_emr1			[expr {$dmc_baseaddr + 0x64}]
   set dmc_emr2			[expr {$dmc_baseaddr + 0x68}]
   set dmc_dllctl		[expr {$dmc_baseaddr + 0x80}]
   set dmc_phy_ctl0		[expr {$dmc_baseaddr + 0x1000}]
   set dmc_phy_ctl1		[expr {$dmc_baseaddr + 0x1004}]
   set dmc_phy_ctl2		[expr {$dmc_baseaddr + 0x1008}]
   set dmc_phy_ctl3		[expr {$dmc_baseaddr + 0x100c}]
   set dmc_phy_ctl4		[expr {$dmc_baseaddr + 0x1010}]
   set dmc_cal_padctl0	[expr {$dmc_baseaddr + 0x1034}]
   set dmc_cal_padctl2	[expr {$dmc_baseaddr + 0x103c}]

   # Configure SMPU (silicon anomaly 20000018)
   smpu_config 0
   smpu_config 8
   smpu_config 10

   # Set the RESETDLL bit (bit 11 of the DMC_PHY_CTL0 register) before CGU Initialization.
   # *pREG_DMC0_PHY_CTL0 |= BITM_DMC_PHY_CTL0_RESETDLL;
   pmmw $dmc_phy_ctl0 0x800 0

   # Set CGU clock select register to CLKO2/4 (ARM core)
   mww phys 0x3108d010 4

   # Reset processor to default power settings
   # Clear DISABLE and set EXIT_ACTIVE in CGU0_PLLCTL
   mww phys 0x3108d004 0x2
   # Set DF = 0 MSEL = 0x10 in CGU0_CTL
   mww phys 0x3108d000 0x1000
   # Set SYSSEL = 2 S0SEL = 2 S1SEL = 2 CSEL = 1 DSEL = 1 in CGU0_DIV
   mww phys 0x3108d00c 0x44014241

   # Read CGU0_STAT to make sure it's in FULL ON mode
   #mdw phys 0x3108d008

   # Clear the PHY_CTL0 after CGU Initialization
   mww phys $dmc_phy_ctl0 0

   # Wait for DLL lock - 9000 DCLK cycles
   # 1ms should be enough
   after 1

   # *pREG_DMC0_PHY_CTL0 |= 0x0000000F;
   pmmw $dmc_phy_ctl0 0xf 0
   # *pREG_DMC0_PHY_CTL2 |= 0xFC000000;
   pmmw $dmc_phy_ctl2 0xfc000000 0
   # *pREG_DMC0_PHY_CTL3 |= 0x0A0000C0;
   pmmw $dmc_phy_ctl3 0xa0000c0 0

   # *pREG_DMC0_PHY_CTL1 = 0x00000000;
   mww phys $dmc_phy_ctl1 0

   # *pREG_DMC0_PHY_CTL4 = 0x00000001;
   mww phys $dmc_phy_ctl4 1

   # Program the PAD RTT and driver impedance values required here
   # *pREG_DMC0_CAL_PADCTL0 = 0xE0000000;
   mww phys $dmc_cal_padctl0 0xe0000000
   # *pREG_DMC0_CAL_PADCTL2 = 0x0078283C;
   mww phys $dmc_cal_padctl2 0x0078283c

   # Start calibration
   # *pREG_DMC0_CAL_PADCTL0 |= 0x10000000;
   pmmw $dmc_cal_padctl0 0x10000000 0

   # Wait for PAD calibration to complete - 300 DCLK cycle.
   # 1ms should be enough
   after 1

   # *pREG_DMC0_CFG = 0x00000522;
   mww phys $dmc_cfg 0x00000522
   # *pREG_DMC0_TR0 = 0x21610535;
   mww phys $dmc_tr0 0x21610535
   # *pREG_DMC0_TR1 = 0x404e0c30;
   mww phys $dmc_tr1 0x404e0c30
   # *pREG_DMC0_TR2 = 0x00326312;
   mww phys $dmc_tr2 0x00326312
   # *pREG_DMC0_MR = 0x00000a52;
   mww phys $dmc_mr 0x00000a52
   # *pREG_DMC0_EMR1 = 0x00000004;
   mww phys $dmc_emr1 0x00000004
   # *pREG_DMC0_EMR2 = 0x00000000;
   mww phys $dmc_emr2 0x00000000
   # *pREG_DMC0_CTL = 0x00000404;
   mww phys $dmc_ctl 0x00000404

   # Wait till INITDONE is set
   # while((*pREG_DMC0_STAT&BITM_DMC_STAT_INITDONE)==0);
   set data 0
   while { [expr {$data & 4}] == 0 } {
      set data [pmemread32 $dmc_stat]
   }

   # *pREG_DMC0_DLLCTL = 0x00000948;
   mww phys $dmc_dllctl 0x00000948

   # Workaround for silicon anomaly 20000037
   # Dummy read
   set data [memread32 $dummy_addr]
   # *pREG_DMC0_PHY_CTL0|=0x1000;
   # *pREG_DMC0_PHY_CTL0&=~0x1000;
   set data [pmemread32 $dmc_phy_ctl0]
   mww phys $dmc_phy_ctl0 [expr {$data | 0x1000}]
   mww phys $dmc_phy_ctl0 [expr {$data & ~0x1000}]
}

proc adspsc59x_init_ddr3 { dmc } {
   global CHIPNAME

   set dmc_baseaddr       0x31070000
   set dmc_ctl            [expr {$dmc_baseaddr + 0x4}]
   set dmc_stat           [expr {$dmc_baseaddr + 0x8}]
   set dmc_cfg            [expr {$dmc_baseaddr + 0x40}]
   set dmc_tr0            [expr {$dmc_baseaddr + 0x44}]
   set dmc_tr1            [expr {$dmc_baseaddr + 0x48}]
   set dmc_tr2            [expr {$dmc_baseaddr + 0x4c}]
   set dmc_mr             [expr {$dmc_baseaddr + 0x60}]
   set dmc_mr1            [expr {$dmc_baseaddr + 0x64}]
   set dmc_mr2            [expr {$dmc_baseaddr + 0x68}]
   set dmc_emr3           [expr {$dmc_baseaddr + 0x6C}]
   set dmc_dllctl         [expr {$dmc_baseaddr + 0x80}]
   set dmc_ddr_lane0_ctl0 [expr {$dmc_baseaddr + 0x1000}]
   set dmc_ddr_lane0_ctl1 [expr {$dmc_baseaddr + 0x1004}]
   set dmc_ddr_lane1_ctl0 [expr {$dmc_baseaddr + 0x100C}]
   set dmc_ddr_lane1_ctl1 [expr {$dmc_baseaddr + 0x1010}]
   set dmc_ddr_root_ctl   [expr {$dmc_baseaddr + 0x1018}]
   set dmc_ddr_zq_ctl0    [expr {$dmc_baseaddr + 0x1034}]
   set dmc_ddr_zq_ctl1    [expr {$dmc_baseaddr + 0x1038}]
   set dmc_ddr_zq_ctl2    [expr {$dmc_baseaddr + 0x103C}]
   set dmc_ddr_ca_ctl     [expr {$dmc_baseaddr + 0x1068}]
   set dmc_ddr_scratch2   [expr {$dmc_baseaddr + 0x1074}]
   set dmc_ddr_scratch3   [expr {$dmc_baseaddr + 0x1078}]
   set dmc_ddr_scratch6   [expr {$dmc_baseaddr + 0x1084}]
   set dmc_ddr_scratch7   [expr {$dmc_baseaddr + 0x1088}]

   set cgu0_ctl           0x3108d000
   set cgu0_pllctl        [expr {$cgu0_ctl + 0x4}]
   set cgu0_stat          [expr {$cgu0_ctl + 0x8}]
   set cgu0_div           [expr {$cgu0_ctl + 0xC}]
   set cgu0_clkoutsel     [expr {$cgu0_ctl + 0x10}]
   set cgu0_divex         [expr {$cgu0_ctl + 0x40}]

   set cgu1_ctl           0x3108e000
   set cgu1_pllctl        [expr {$cgu1_ctl + 0x4}]
   set cgu1_stat          [expr {$cgu1_ctl + 0x8}]
   set cgu1_div           [expr {$cgu1_ctl + 0xC}]
   set cgu1_clkoutsel     [expr {$cgu1_ctl + 0x10}]
   set cgu1_divex         [expr {$cgu1_ctl + 0x40}]

   set cdu_cfg0  0x3108f000
   set cdu_cfg1  [expr {$cdu_cfg0 + 0x4}]
   set cdu_cfg2  [expr {$cdu_cfg0 + 0x8}]
   set cdu_cfg3  [expr {$cdu_cfg0 + 0xc}]
   set cdu_cfg4  [expr {$cdu_cfg0 + 0x10}]
   set cdu_cfg5  [expr {$cdu_cfg0 + 0x14}]
   set cdu_cfg6  [expr {$cdu_cfg0 + 0x18}]
   set cdu_cfg7  [expr {$cdu_cfg0 + 0x1C}]
   set cdu_cfg8  [expr {$cdu_cfg0 + 0x20}]
   set cdu_cfg9  [expr {$cdu_cfg0 + 0x24}]
   set cdu_cfg10 [expr {$cdu_cfg0 + 0x28}]
   set cdu_cfg11 [expr {$cdu_cfg0 + 0x2C}]
   set cdu_cfg12 [expr {$cdu_cfg0 + 0x30}]

   set cdu_stat      0x3108f040
   set cdu_clkinsel  [expr {$cdu_stat + 0x4}]

   set canfd0_base 0x31046000
   set canfd1_base 0x31047000

   # Reset DMC Lane by setting the DMC_DDR_LANE0_CTL0.CB_RSTDLL
   # and DMC_DDR_LANE1_CTL0.CB_RSTDLL bits
   # *pREG_DMC0_DDR_LANE0_CTL0 |= BITM_DMC_DDR_LANE0_CTL0_CB_RSTDLL;
   # *pREG_DMC0_DDR_LANE1_CTL0 |= BITM_DMC_DDR_LANE1_CTL0_CB_RSTDLL;
   pmmw $dmc_ddr_lane0_ctl0 0x100 0x0
   pmmw $dmc_ddr_lane1_ctl0 0x100 0x0
   
   # Wait for DLL lock - 9000 DCLK cycles
   # 1ms should be enough
   after 1

   # Configure the CDU
   set cdu_cfg_in0_en 0x1
   set cdu_cfg_in1_en 0x3

   mww phys $cdu_cfg0 $cdu_cfg_in0_en
   mww phys $cdu_cfg1 $cdu_cfg_in0_en
   mww phys $cdu_cfg2 $cdu_cfg_in0_en
   mww phys $cdu_cfg3 $cdu_cfg_in1_en
   mww phys $cdu_cfg4 $cdu_cfg_in1_en
   mww phys $cdu_cfg5 $cdu_cfg_in0_en
   mww phys $cdu_cfg6 $cdu_cfg_in0_en
   mww phys $cdu_cfg7 $cdu_cfg_in0_en
   mww phys $cdu_cfg8 $cdu_cfg_in1_en
   mww phys $cdu_cfg9 $cdu_cfg_in0_en
   mww phys $cdu_cfg10 $cdu_cfg_in0_en
   mww phys $cdu_cfg12 $cdu_cfg_in0_en

   # CGU0 Configuration
   # If PLL is disabled, then enable it
   # if(!(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLEN))
   #  {pDevice->pCguRegs->CGU_CTL |= BITM_CGU_PLLCTL_PLLEN;}
   if { ![expr {$cgu0_stat & 0x1}] } {
      pmmw $cgu0_ctl 0x8 0x0
   }

   # If PLL is bypassed, then switch power mode from Active to Full on
   # if(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLBP)
   # pDevice->pCguRegs->CGU_PLLCTL = BITM_CGU_PLLCTL_PLLBPCL;
   if { [expr {$cgu0_stat & 0x2}] } {
      mww phys $cgu0_pllctl 0x2
   }

   # Set CGU0_DIV
   # pADI_CGU_Param_List.cgu0_settings.clocksettings.div_CSEL        = 2;
   # pADI_CGU_Param_List.cgu0_settings.clocksettings.div_S0SEL       = 4;
   # pADI_CGU_Param_List.cgu0_settings.clocksettings.div_SYSSEL      = 4;
   # pADI_CGU_Param_List.cgu0_settings.clocksettings.div_S1SEL       = 2;
   # pADI_CGU_Param_List.cgu0_settings.clocksettings.div_DSEL        = 2;
   # pADI_CGU_Param_List.cgu0_settings.clocksettings.div_OSEL        = 8;
   # pADI_CGU_Param_List.cgu0_settings.clocksettings.divex_S1SELEX   = 6;
   mww phys $cgu0_div 0x2024482

   # Put PLL in to Bypass Mode
   # regValue = BITM_CGU_PLLCTL_PLLEN | BITM_CGU_PLLCTL_PLLBPST;
   # pDevice->pCguRegs->CGU_PLLCTL = regValue;
   # Wait for Bypass to reflect in the status
   # while(!(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLBP)) {};
   mww phys $cgu0_pllctl 0x9
   set data [pmemread32 $cgu0_stat]
   while { ![expr {$data & 0x2}] } {
      set data [pmemread32 $cgu0_stat]
   }

   # Program the CTL register
   # pDevice->pCguRegs->CGU_CTL =  dNewCguCtl;
   mww phys $cgu0_ctl 0x25000

   # Wait until the S1SELEXEN enable bit is actually set
   # while(!(pDevice->pCguRegs->CGU_CTL & BITM_CGU_CTL_S1SELEXEN)) {}
   set data [pmemread32 $cgu0_ctl]
   while { ![expr {$data & 0x20000}] } {
      set data [pmemread32 $cgu0_ctl]
   }

   # Take PLL out of Bypass Mode
   # regValue = BITM_CGU_PLLCTL_PLLEN | BITM_CGU_PLLCTL_PLLBPCL;
   # pDevice->pCguRegs->CGU_PLLCTL = regValue;
   # Wait for No-Bypass to reflect in the status
   # while(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLBP) {}
   # Wait until clocks are aligned
   # while(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_CLKSALGN)
   mww phys $cgu0_pllctl 0xa
   set data [pmemread32 $cgu0_stat]
   while { [expr {$data & 0x2}] } {
      set data [pmemread32 $cgu0_stat]
   }
   while { [expr {$data & 0x8}] } {
      set data [pmemread32 $cgu0_stat]
   }
   
   # CGU1 Configuration

   # Configure CDU_CLKINSEL, which requires us to bypass CGU0 PLL

   # Put PLL in to Bypass Mode
   # regValue = BITM_CGU_PLLCTL_PLLEN | BITM_CGU_PLLCTL_PLLBPST;
   # pDevice->pCguRegs->CGU_PLLCTL = regValue;
   # Wait for Bypass to reflect in the status
   # while(!(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLBP)) {};
   mww phys $cgu0_pllctl 0x9
   set data [pmemread32 $cgu0_stat]
   while { ![expr {$data & 0x2}] } {
      set data [pmemread32 $cgu0_stat]
   }

   # Update the new Divider values for S1SELEX via DIVEX
   # pDevice->pCguRegs->CGU_DIVEX = dNewCguSCLKExDiv | ADI_PWR_SCLK0EXDIV_DEF_VAL;
   mww phys $cgu0_divex 0x60030

   # Write to the CDU_CLKINSEL register
   # eCguSelect = 0
   # regValue &= (uint32_t)(~(((uint32_t)1u) << (uint32_t)eCguSelect));
   # regValue |= ((uint32_t)eClkSelect << (uint32_t)eCguSelect);
   # *pREG_CDU0_CLKINSEL = regValue;
   mww phys $cdu_clkinsel 0

   # Take PLL out of Bypass Mode and then wait for clocks to align
   mww phys $cgu0_pllctl 0xa
   set data [pmemread32 $cgu0_stat]
   while { [expr {$data & 0x2}] } {
      set data [pmemread32 $cgu0_stat]
   }
   while { [expr {$data & 0x8}] } {
      set data [pmemread32 $cgu0_stat]
   }

   # Enable PLL for CGU1
   # If PLL is disabled, then enable it
   # if(!(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLEN))
   #  {pDevice->pCguRegs->CGU_CTL |= BITM_CGU_PLLCTL_PLLEN;}
   pmmw $cgu1_ctl 0x8 0x0

   # If PLL is bypassed, then switch power mode from Active to Full on
   # if(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLBP)
   # pDevice->pCguRegs->CGU_PLLCTL = BITM_CGU_PLLCTL_PLLBPCL;
   # Wait for alignment to be done
   # while(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_CLKSALGN){};
   mww phys $cgu1_pllctl 0x2
   set data [pmemread32 $cgu1_stat]
   while { [expr {$data & 0x8}] } {
      set data [pmemread32 $cgu1_stat]
   }

   # Set CGU1_DIV
   # pADI_CGU_Param_List.cgu1_settings.clocksettings.div_CSEL        = 2;
   # pADI_CGU_Param_List.cgu1_settings.clocksettings.div_S0SEL       = 4;
   # pADI_CGU_Param_List.cgu1_settings.clocksettings.div_SYSSEL      = 4;
   # pADI_CGU_Param_List.cgu1_settings.clocksettings.div_S1SEL       = 2;
   # pADI_CGU_Param_List.cgu1_settings.clocksettings.div_DSEL        = 2;
   # pADI_CGU_Param_List.cgu1_settings.clocksettings.div_OSEL        = 16;
   # pADI_CGU_Param_List.cgu1_settings.clocksettings.divex_S1SELEX   = 0;
   mww phys $cgu1_div 0x4024482

   # Put PLL in to Bypass Mode
   # regValue = BITM_CGU_PLLCTL_PLLEN | BITM_CGU_PLLCTL_PLLBPST;
   # pDevice->pCguRegs->CGU_PLLCTL = regValue;
   # Wait for Bypass to reflect in the status
   # while(!(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLBP)) {}
   mww phys $cgu1_pllctl 0x9
   set data [pmemread32 $cgu1_stat]
   while { ![expr {$data & 0x2}] } {
      set data [pmemread32 $cgu1_stat]
   }

   # Program the CTL register
   # pDevice->pCguRegs->CGU_CTL =  dNewCguCtl;
   mww phys $cgu1_ctl 0x24000

   # Take PLL out of Bypass Mode
   # regValue = BITM_CGU_PLLCTL_PLLEN | BITM_CGU_PLLCTL_PLLBPCL;
   # pDevice->pCguRegs->CGU_PLLCTL = regValue;
   # Wait for No-Bypass to reflect in the status
   # while(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_PLLBP) {}
   # Wait until clocks are aligned
   # while(pDevice->pCguRegs->CGU_STAT & BITM_CGU_STAT_CLKSALGN)
   mww phys $cgu1_pllctl 0xa
   set data [pmemread32 $cgu1_stat]
   while { [expr {$data & 0x2}] } {
      set data [pmemread32 $cgu1_stat]
   }
   while { [expr {$data & 0x8}] } {
      set data [pmemread32 $cgu1_stat]
   }

   # Clear DMC Lane reset by clearing DMC_DDR_LANE0_CTL0.CB_RSTDLL
   # and DMC_DDR_LANE1_CTL0.CB_RSTDLL bits
   # *pREG_DMC0_DDR_LANE0_CTL0 &= ~BITM_DMC_DDR_LANE0_CTL0_CB_RSTDLL;
   # *pREG_DMC0_DDR_LANE1_CTL0 &= ~BITM_DMC_DDR_LANE1_CTL0_CB_RSTDLL;
   pmmw $dmc_ddr_lane0_ctl0 0x0 0x100
   pmmw $dmc_ddr_lane1_ctl0 0x0 0x100

   # Wait for DLL lock - 9000 DCLK cycles
   # 1ms should be enough
   after 1

   # Workaround for DDR calibration is required for SC59x 0.0 silicon
   set ddr_workaround 1

   if { $ddr_workaround } {
      # /* DMC Phy Initialization function with workaround 2 */
      # /* Reset trigger */
      # *pREG_DMC0_DDR_CA_CTL = 0x0;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x0;
      # DmcDelay(5000);
      mww phys $dmc_ddr_ca_ctl 0
      mww phys $dmc_ddr_root_ctl 0
      after 1

      # *pREG_DMC0_DDR_SCRATCH_3 = 0x0;
      # *pREG_DMC0_DDR_SCRATCH_2 = 0x0;
      # DmcDelay(5000);
      mww phys $dmc_ddr_scratch3 0
      mww phys $dmc_ddr_scratch2 0
      after 1

      # /* Writing internal registers IN calib pad to zero. Calib mode set to 1 [26], trig M1 S1 write [16],
      # * this enables usage of scratch registers instead of ZQCTL registers */
      # *pREG_DMC0_DDR_ROOT_CTL = 0x04010000;
      # DmcDelay(5000);
      mww phys $dmc_ddr_root_ctl 0x4010000
      after 1

      # /* TRIGGER FOR M2-S2 WRITE     -> slave id 31:26  trig m2,s2 write bit 1->1
      # slave1 address is 4 */
      # *pREG_DMC0_DDR_CA_CTL = 0x10000002 ;
      # DmcDelay(5000);
      mww phys $dmc_ddr_ca_ctl 0x10000002 
      after 1

      # /* reset Trigger */
      # *pREG_DMC0_DDR_CA_CTL = 0x0;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x0
      mww $dmc_ddr_ca_ctl 0
      mww $dmc_ddr_root_ctl 0

      # /* write to slave 1, make the power down bit high */
      # *pREG_DMC0_DDR_SCRATCH_3 = 0x1<<12;
      # *pREG_DMC0_DDR_SCRATCH_2 = 0x0;
      # DmcDelay(5000);
      mww $dmc_ddr_scratch3 0x1000
      mww $dmc_ddr_scratch2 0
      after 1

      # /* Calib mode set to 1 [26], trig M1 S1 write [16] */
      # *pREG_DMC0_DDR_ROOT_CTL = 0x04010000;
      # DmcDelay(5000);
      mww $dmc_ddr_root_ctl 0x04010000
      after 1

      # *pREG_DMC0_DDR_CA_CTL = 0x10000002;
      # DmcDelay(5000);
      mww $dmc_ddr_ca_ctl 0x10000002 
      after 1

      # *pREG_DMC0_DDR_CA_CTL = 0x0;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x0;
      # DmcDelay(5000);
      mww $dmc_ddr_ca_ctl 0
      mww $dmc_ddr_root_ctl 0
      after 1

      # /* for slave 0 */
      # *pREG_DMC0_DDR_SCRATCH_2 = pConfig->ulDDR_ZQCTL0;
      # DmcDelay(5000);
      mww $dmc_ddr_scratch2 0x786464
      after 1

      # /* Calib mode set to 1 [26], trig M1 S1 write [16] */
      # *pREG_DMC0_DDR_ROOT_CTL = 0x04010000;
      # DmcDelay(5000);
      mww $dmc_ddr_root_ctl 0x04010000
      after 1

      # *pREG_DMC0_DDR_CA_CTL = 0x0C000002 ;
      # DmcDelay(5000);
      mww $dmc_ddr_ca_ctl 0x0c000002
      after 1

      # *pREG_DMC0_DDR_CA_CTL = 0x0;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x0;
      # DmcDelay(5000);
      mww $dmc_ddr_ca_ctl 0
      mww $dmc_ddr_root_ctl 0
      after 1

      # /* writing to slave 1
      # calstrt is 0, but other programming is done */
      # *pREG_DMC0_DDR_SCRATCH_3 = 0x0; /* make power down LOW again, to kickstart BIAS circuit */
      # *pREG_DMC0_DDR_SCRATCH_2 = 0x70000000;
      #    DmcDelay(5000);
      mww $dmc_ddr_scratch3 0x0
      mww $dmc_ddr_scratch2 0x70000000
      after 1

      # /* write to ca_ctl lane, calib mode set to 1 [26], trig M1 S1 write [16]*/
      # *pREG_DMC0_DDR_ROOT_CTL = 0x04010000;
      # DmcDelay(5000);
      mww $dmc_ddr_root_ctl 0x04010000
      after 1

      # /*  copies data to lane controller slave
      # TRIGGER FOR M2-S2 WRITE     -> slave id 31:26  trig m2,s2 write bit 1->1
      # slave1 address is 4 */
      # *pREG_DMC0_DDR_CA_CTL = 0x10000002 ;
      # DmcDelay(5000);
      mww $dmc_ddr_ca_ctl 0x10000002
      after 1

      # /* reset Trigger */
      # *pREG_DMC0_DDR_CA_CTL = 0x0;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x0;
      mww $dmc_ddr_ca_ctl 0
      mww $dmc_ddr_root_ctl 0

   } else {
      # Begin DMC phy ZQ calibration routine
      # Program the ODT and drive strength values
      # *pREG_DMC0_DDR_ZQ_CTL0 = 0x00786464;
      # *pREG_DMC0_DDR_ZQ_CTL1 = 0;
      # *pREG_DMC0_DDR_ZQ_CTL2 = 0x70000000;
      mww phys $dmc_ddr_zq_ctl0 0x786464
      mww phys $dmc_ddr_zq_ctl1 0
      mww phys $dmc_ddr_zq_ctl2 0x70000000

      # Generate the trigger
      # *pREG_DMC0_DDR_CA_CTL = 0x00000000ul ;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x00000000ul;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x00010000ul;
      # dmcdelay(8000);
      #
      # The [31:26] bits may change if pad ring changes */
      # *pREG_DMC0_DDR_CA_CTL = 0x0C000001ul|TrigCalib;
      # dmcdelay(8000);
      # *pREG_DMC0_DDR_CA_CTL = 0x00000000ul ;
      # *pREG_DMC0_DDR_ROOT_CTL = 0x00000000ul ;

      mww phys $dmc_ddr_ca_ctl 0
      mww phys $dmc_ddr_root_ctl 0
      mww phys $dmc_ddr_root_ctl 0x10000
      after 1

      mww phys $dmc_ddr_ca_ctl 0x0c000001
      after 1
      mww phys $dmc_ddr_ca_ctl 0
      mww phys $dmc_ddr_root_ctl 0

   }


   # The following are not required for EV-SC594-SOM DDR3 initialization
   # /* Tdqs fine tune setting */
   # if (pDMCInfo->DelayTrim)
   # {
   #    pDMCInfo->pPreg->Lane0Control1|= (((pDMCInfo->Bypasscode)<<BITP_DMC_DDR_LANE0_CTL1_BYPCODE) & BITM_DMC_DDR_LANE0_CTL1_BYPCODE)|BITM_DMC_DDR_LANE0_CTL1_BYPDELCHAINEN;
   #    pDMCInfo->pPreg->Lane1Control1|=(((pDMCInfo->Bypasscode)<<BITP_DMC_DDR_LANE1_CTL1_BYPCODE) & BITM_DMC_DDR_LANE1_CTL1_BYPCODE)|BITM_DMC_DDR_LANE1_CTL1_BYPDELCHAINEN;
   # }

   # /* DQS duty trim */
   # if(pDMCInfo->DqsTrim)
   # {
   #    pDMCInfo->pPreg->Lane0Control0|= ((pDMCInfo->Dqscode)<<BITP_DMC_DDR_LANE0_CTL0_BYPENB) & (BITM_DMC_DDR_LANE1_CTL0_BYPENB|BITM_DMC_DDR_LANE0_CTL0_BYPSELP|BITM_DMC_DDR_LANE0_CTL0_BYPCODE);
   #    pDMCInfo->pPreg->Lane1Control0|=((pDMCInfo->Dqscode)<<BITP_DMC_DDR_LANE1_CTL0_BYPENB) & (BITM_DMC_DDR_LANE1_CTL1_BYPCODE|BITM_DMC_DDR_LANE1_CTL0_BYPSELP|BITM_DMC_DDR_LANE1_CTL0_BYPCODE);
   # }

   # /* Clock duty trim */
   # if(pDMCInfo->ClkTrim)
   # {
   #    pDMCInfo->pPreg->CaControl|=(((pDMCInfo->Clkcode) & 0xfu) <<BITP_DMC_DDR_CA_CTL_BYPENB)|(((pDMCInfo->Clkcode) >> 4u) <<BITP_DMC_DDR_CA_CTL_BYPCODE1);
   # }

   # Initialize the DMC Controller

   # Program timing registers
   # *pREG_DMC0_CFG = (pConfig->ulDDR_DLLCTLCFG) & 0xFFFFul;
   # *pREG_DMC0_TR0 = pConfig->ulDDR_TR0;
   # *pREG_DMC0_TR1 = pConfig->ulDDR_TR1;
   # *pREG_DMC0_TR2 = pConfig->ulDDR_TR2;
   mww phys $dmc_cfg 0x722
   mww phys $dmc_tr0 0x4271cb6b
   mww phys $dmc_tr1 0x61181860
   mww phys $dmc_tr2 0x45c620

   # program shadow registers
   # *pREG_DMC0_MR =  ((pConfig->ulDDR_MREMR1) >> 16ul) & 0xFFFFul;
   # *pREG_DMC0_MR1 = (pConfig->ulDDR_MREMR1) & 0xFFFFul;
   # *pREG_DMC0_MR2 = (pConfig->ulDDR_EMR2EMR3)>>16ul & 0xFFFFul;
   # *pREG_DMC0_EMR3 =(pConfig->ulDDR_EMR2EMR3) & 0xFFFFul;
   mww phys $dmc_mr 0xd70
   mww phys $dmc_mr1 0xc0
   mww phys $dmc_mr2 0x18
   mww phys $dmc_emr3 0x4

   # program Dll timing register
   # *pREG_DMC0_DLLCTL = ((pConfig->ulDDR_DLLCTLCFG) >> 16ul) & 0xFFFFul;
   # dmcdelay(2000);
   # *pREG_DMC0_DDR_CA_CTL |=BITM_DMC_DDR_CA_CTL_SW_REFRESH;
   # dmcdelay(5);
   # *pREG_DMC0_DDR_ROOT_CTL |= BITM_DMC_DDR_ROOT_CTL_SW_REFRESH | (OfstdCycle << BITP_DMC_DDR_ROOT_CTL_PIPE_OFSTDCYCLE);
   mww phys $dmc_dllctl 0xcf0
   after 1
   mww phys $dmc_ddr_ca_ctl 0x4000
   after 1
   mww phys $dmc_ddr_root_ctl 0x2800

   # *pREG_DMC0_CTL       = pConfig->ulDDR_CTL;
   # dmcdelay(722000);
   mww phys $dmc_ctl 0x8000a05

   # Delay for a while - initcode checks registers but we can
   # assume a conservative delay time
   after 1

   # End of DMC controller configuration, Start of Phy control registers
   # toggle DCYCLE
   # *pREG_DMC0_DDR_LANE0_CTL1 |= BITM_DMC_DDR_LANE0_CTL1_COMP_DCYCLE;
   # *pREG_DMC0_DDR_LANE1_CTL1 |= BITM_DMC_DDR_LANE1_CTL1_COMP_DCYCLE;
   # dmcdelay(10);
   # *pREG_DMC0_DDR_LANE0_CTL1 &= (~BITM_DMC_DDR_LANE0_CTL1_COMP_DCYCLE);
   # *pREG_DMC0_DDR_LANE1_CTL1 &= (~BITM_DMC_DDR_LANE1_CTL1_COMP_DCYCLE);
   pmmw $dmc_ddr_lane0_ctl1 0x2 0x0
   pmmw $dmc_ddr_lane1_ctl1 0x2 0x0
   after 1
   pmmw $dmc_ddr_lane0_ctl1 0x0 0x2
   pmmw $dmc_ddr_lane1_ctl1 0x0 0x2

   # toggle RSTDAT
   # *pREG_DMC0_DDR_LANE0_CTL0 |= BITM_DMC_DDR_LANE0_CTL0_CB_RSTDAT;
   # *pREG_DMC0_DDR_LANE0_CTL0 &= (~BITM_DMC_DDR_LANE0_CTL0_CB_RSTDAT);
   # *pREG_DMC0_DDR_LANE1_CTL0 |= BITM_DMC_DDR_LANE1_CTL0_CB_RSTDAT;
   # *pREG_DMC0_DDR_LANE1_CTL0 &= (~BITM_DMC_DDR_LANE1_CTL0_CB_RSTDAT);
   # dmcdelay(2500);
   pmmw $dmc_ddr_lane0_ctl0 0x08000000 0x0
   pmmw $dmc_ddr_lane0_ctl0 0x0 0x08000000
   pmmw $dmc_ddr_lane1_ctl0 0x08000000 0x0
   pmmw $dmc_ddr_lane1_ctl0 0x0 0x08000000
   after 1

   # Program phyphase
   # phyphase = (*pREG_DMC0_STAT & BITM_DMC_STAT_PHYRDPHASE)>>BITP_DMC_STAT_PHYRDPHASE;
   # data_cyc= (phyphase << BITP_DMC_DLLCTL_DATACYC) & BITM_DMC_DLLCTL_DATACYC;
   # rd_cnt = ((pConfig->ulDDR_DLLCTLCFG) >> 16);
   # rd_cnt <<= BITP_DMC_DLLCTL_DLLCALRDCNT;
   # rd_cnt &= BITM_DMC_DLLCTL_DLLCALRDCNT;
   # *pREG_DMC0_DLLCTL =rd_cnt|data_cyc;
   # *pREG_DMC0_CTL = (pConfig->ulDDR_CTL & (~BITM_DMC_CTL_INIT) & (~BITM_DMC_CTL_RL_DQS));
   set data_stat [pmemread32 $dmc_stat]
   set phyphase [expr {$data_stat & 0x00f00000}]
   set phyphase [expr {$phyphase >> 20}]
   set datacyc [expr {$phyphase << 8}]
   set datacyc [expr {$datacyc & 0x00000f00}]
   set rd_cnt 0xf0
   mww phys $dmc_dllctl [expr {$rd_cnt | $datacyc}]
   mww phys $dmc_ctl [expr {0x8000a05 & ~0x4 & ~0x04000000}]

   # Initialize CANFD
   canfd_config $canfd0_base
   canfd_config $canfd1_base
}
