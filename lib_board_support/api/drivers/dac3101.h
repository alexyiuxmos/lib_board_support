// Copyright 2024-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef DAC3101_H_
#define DAC3101_H_

//Address on I2C bus
#define DAC3101_I2C_ADDR 0x18

// TLV320DAC3101 Register Addresses
// Page 0
#define DAC3101_PAGE_CTRL     0x00 // Register 0 - Page Control
#define DAC3101_SW_RST        0x01 // Register 1 - Software Reset
#define DAC3101_CLK_GEN_MUX   0x04 // Register 4 - Clock-Gen Muxing
#define DAC3101_PLL_P_R       0x05 // Register 5 - PLL P and R Values
#define DAC3101_PLL_J         0x06 // Register 6 - PLL J Value
#define DAC3101_PLL_D_MSB     0x07 // Register 7 - PLL D Value (MSB)
#define DAC3101_PLL_D_LSB     0x08 // Register 8 - PLL D Value (LSB)
#define DAC3101_NDAC_VAL      0x0B // Register 11 - NDAC Divider Value
#define DAC3101_MDAC_VAL      0x0C // Register 12 - MDAC Divider Value
#define DAC3101_DOSR_VAL_MSB  0x0D // Register 13 - DOSR Divider Value (MS Byte)
#define DAC3101_DOSR_VAL_LSB  0x0E // Register 14 - DOSR Divider Value (LS Byte)
#define DAC3101_CLKOUT_MUX    0x19 // Register 25 - CLKOUT MUX
#define DAC3101_CLKOUT_M_VAL  0x1A // Register 26 - CLKOUT M_VAL
#define DAC3101_CODEC_IF      0x1B // Register 27 - CODEC Interface Control
#define DAC3101_B_DIV_VAL     0x1E // Register 30 - BCLK Divider
#define DAC3101_DAC_DAT_PATH  0x3F // Register 63 - DAC Data Path Setup
#define DAC3101_DAC_VOL       0x40 // Register 64 - DAC Vol Control
#define DAC3101_DACL_VOL_D    0x41 // Register 65 - DAC Left Digital Vol Control
#define DAC3101_DACR_VOL_D    0x42 // Register 66 - DAC Right Digital Vol Control
#define DAC3101_GPIO1_IO      0x33 // Register 51 - GPIO1 In/Out Pin Control
// Page 1
#define DAC3101_HP_DRVR       0x1F // Register 31 - Headphone Drivers
#define DAC3101_SPK_AMP       0x20 // Register 32 - Class-D Speaker Amp
#define DAC3101_HP_DEPOP      0x21 // Register 33 - Headphone Driver De-pop
#define DAC3101_DAC_OP_MIX    0x23 // Register 35 - DAC_L and DAC_R Output Mixer Routing
#define DAC3101_HPL_VOL_A     0x24 // Register 36 - Analog Volume to HPL
#define DAC3101_HPR_VOL_A     0x25 // Register 37 - Analog Volume to HPR
#define DAC3101_SPKL_VOL_A    0x26 // Register 38 - Analog Volume to Left Speaker
#define DAC3101_SPKR_VOL_A    0x27 // Register 39 - Analog Volume to Right Speaker
#define DAC3101_HPL_DRVR      0x28 // Register 40 - Headphone Left Driver
#define DAC3101_HPR_DRVR      0x29 // Register 41 - Headphone Right Driver
#define DAC3101_SPKL_DRVR     0x2A // Register 42 - Left Class-D Speaker Driver
#define DAC3101_SPKR_DRVR     0x2B // Register 43 - Right Class-D Speaker Driver

//=========================================================================================

// App PLL setup
#define APP_PLL_CTL_BYPASS       (0)   // 0 = no bypass, 1 = bypass.
#define APP_PLL_CTL_INPUT_SEL    (0)   // 0 = XTAL, 1 = sysPLL
#define APP_PLL_CTL_ENABLE_BIT   (1)   // 0 = disabled, 1 = enabled.

// 24MHz in, 24.576MHz out, integer mode
// Found exact solution:   IN  24000000.0, OUT  24576000.0, VCO 2457600000.0, RD  5, FD  512, OD 10, FOD  10
#define APP_PLL_CTL_OD_48        (4)   // Output divider = (OD+1)
#define APP_PLL_CTL_F_48         (511) // FB divider = (F+1)/2
#define APP_PLL_CTL_R_48         (4)   // Ref divider = (R+1)

#define APP_PLL_CTL_48           ((APP_PLL_CTL_BYPASS << 29) | (APP_PLL_CTL_INPUT_SEL << 28) | (APP_PLL_CTL_ENABLE_BIT << 27) |\
                                    (APP_PLL_CTL_OD_48 << 23) | (APP_PLL_CTL_F_48 << 8) | APP_PLL_CTL_R_48)

// Fractional divide is M/N
#define APP_PLL_FRAC_EN_48             (0)   // 0 = disabled
#define APP_PLL_FRAC_NPLUS1_CYCLES_48  (0)   // M value is this reg value + 1.
#define APP_PLL_FRAC_TOTAL_CYCLES_48   (0)   // N value is this reg value + 1.
#define APP_PLL_FRAC_48          ((APP_PLL_FRAC_EN_48 << 31) | (APP_PLL_FRAC_NPLUS1_CYCLES_48 << 8) | APP_PLL_FRAC_TOTAL_CYCLES_48)

// 24MHz in, 22.5792MHz out (44.1kHz * 512), frac mode
// Found exact solution:   IN  24000000.0, OUT  22579200.0, VCO 2257920000.0, RD  5, FD  470.400 (m =   2, n =   5), OD  5, FOD   10
#define APP_PLL_CTL_OD_441       (4)   // Output divider = (OD+1)
#define APP_PLL_CTL_F_441        (469) // FB divider = (F+1)/2
#define APP_PLL_CTL_R_441        (4)   // Ref divider = (R+1)

#define APP_PLL_CTL_441          ((APP_PLL_CTL_BYPASS << 29) | (APP_PLL_CTL_INPUT_SEL << 28) | (APP_PLL_CTL_ENABLE_BIT << 27) |\
                                    (APP_PLL_CTL_OD_441 << 23) | (APP_PLL_CTL_F_441 << 8) | APP_PLL_CTL_R_441)

#define APP_PLL_FRAC_EN_44             (1)   // 1 = enabled
#define APP_PLL_FRAC_NPLUS1_CYCLES_44  (1)   // M value is this reg value + 1.
#define APP_PLL_FRAC_TOTAL_CYCLES_44   (4)   // N value is this reg value + 1.define APP_PLL_CTL_R_441        (4)   // Ref divider = (R+1)
#define APP_PLL_FRAC_44   ((APP_PLL_FRAC_EN_44 << 31) | (APP_PLL_FRAC_NPLUS1_CYCLES_44 << 8) | APP_PLL_FRAC_TOTAL_CYCLES_44)

#define APP_PLL_DIV_INPUT_SEL    (1)   // 0 = sysPLL, 1 = app_PLL
#define APP_PLL_DIV_DISABLE      (0)   // 1 = disabled (pin connected to X1D11), 0 = enabled divider output to pin.
#define APP_PLL_DIV_VALUE        (4)   // Divide by N+1 - remember there's a /2 also afterwards for 50/50 duty cycle.
#define APP_PLL_DIV              ((APP_PLL_DIV_INPUT_SEL << 31) | (APP_PLL_DIV_DISABLE << 16) | APP_PLL_DIV_VALUE)

#endif /* DAC3101_H_ */
