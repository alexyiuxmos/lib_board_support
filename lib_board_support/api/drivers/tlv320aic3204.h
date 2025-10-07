// Copyright 2024-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef TLV320AIC3204_H_
#define TLV320AIC3204_H_

// TLV320AIC3204 Device I2C Address
#define AIC3204_I2C_DEVICE_ADDR 0x18

// TLV320AIC3204 Register Addresses
// Page 0
#define AIC3204_PAGE_CTRL     0x00 // Register 0  - Page Control
#define AIC3204_SW_RST        0x01 // Register 1  - Software Reset
#define AIC3204_NDAC          0x0B // Register 11 - NDAC Divider Value
#define AIC3204_MDAC          0x0C // Register 12 - MDAC Divider Value
#define AIC3204_DOSR_MSB      0x0d // Register 14 - DOSR Divider Value (MS Byte)
#define AIC3204_DOSR_LSB      0x0e // Register 14 - DOSR Divider Value (LS Byte)
#define AIC3204_NADC          0x12 // Register 18 - NADC Divider Value
#define AIC3204_MADC          0x13 // Register 19 - MADC Divider Value
#define AIC3204_AOSR          0x14 // Register 20 - AOSR Divider Value
#define AIC3204_CLK_MUL       0x19 // Register 25
#define AIC3204_CLK_DIV       0x1A // Register 26
#define AIC3204_CODEC_IF      0x1B // Register 27 - CODEC Interface Control
#define AIC3204_D_OFFSET      0x1C // Register 28 - 
#define AIC3204_LOOPBACK      0x1D // Register 29 - 
#define AIC3204_BCLK_DIV      0x1E // Register 30 - --------
#define AIC3204_CLK_MUL       0x1F  // Register 31 - 
#define AIC3204_BCLK_SEL      0x20  // Register 32 - 0:Primary; 1:Second
#define AIC3204_DAC_SIG_PROC  0x3C // Register 60 - DAC Sig Processing Block Control
#define AIC3204_ADC_SIG_PROC  0x3D // Register 61 - ADC Sig Processing Block Control
#define AIC3204_DAC_CH_SET1   0x3F // Register 63 - DAC Channel Setup 1
#define AIC3204_DAC_CH_SET2   0x40 // Register 64 - DAC Channel Setup 2
#define AIC3204_DACL_VOL_D    0x41 // Register 65 - DAC Left  Digital Vol Control
#define AIC3204_DACR_VOL_D    0x42 // Register 66 - DAC Right Digital Vol Control
#define AIC3204_HEADSET_DET   0x43 // Register 67 - Headset Detection configuration
#define AIC3204_DRC_CON1      0x44 // Register 68 - DRC control reg1
#define AIC3204_DRC_CON2      0x45 // Register 69 - DRC control reg2
#define AIC3204_DRC_CON3      0x46 // Register 70 - DRC control reg3
#define AIC3204_ADC_CH_SET    0x51 // Register 81 - ADC Channel Setup
#define AIC3204_ADC_FGA_MUTE  0x52 // Register 82 - ADC Fine Gain Adjust/Mute
#define AIC3204_ADC_CH1_SET   0x53 // Register 83 - ADC L_CH vol
#define AIC3204_ADC_CH2_SET   0x54 // Register 84 - ADC R_CH vol
#define AIC3204_ADC_PHA_SET   0x55 // Register 84 - ADC Phase Adjust Reg
//0x56~0x5c: L-CH agc control regs
//0x5e~0x65: R-CH agc control regs
///0x66~0x67: DC measurement regs
//0x68~0x6d:  DC Measurement output regs

// Page 1
#define AIC3204_PAGE_SEL1     0x00 // Register 0  - Page Select Reg
#define AIC3204_PWR_CFG       0x01 // Register 1  - Power Config
#define AIC3204_LDO_CTRL      0x02 // Register 2  - LDO Control
#define AIC3204_PLAY_CFG1     0x03 // Register 3  - Playback Config 1
#define AIC3204_PLAY_CFG2     0x04 // Register 4  - Playback Config 2
#define AIC3204_OP_PWR_CTRL   0x09 // Register 9  - Output Driver Power Control
#define AIC3204_CM_CTRL       0x0A // Register 10 - Common Mode Control
#define AIC3204_HPL_ROUTE     0x0C // Register 12 - HPL Routing Select
#define AIC3204_HPR_ROUTE     0x0D // Register 13 - HPR Routing Select
#define AIC3204_HPL_GAIN      0x10 // Register 16 - HPL Driver Gain
#define AIC3204_HPR_GAIN      0x11 // Register 17 - HPR Driver Gain
#define AIC3204_HP_START      0x14 // Register 20 - Headphone Driver Startup
#define AIC3204_LPGA_P_ROUTE  0x34 // Register 52 - Left PGA Positive Input Route
#define AIC3204_LPGA_N_ROUTE  0x36 // Register 54 - Left PGA Negative Input Route
#define AIC3204_RPGA_P_ROUTE  0x37 // Register 55 - Right PGA Positive Input Route
#define AIC3204_RPGA_N_ROUTE  0x39 // Register 57 - Right PGA Negative Input Route
#define AIC3204_LPGA_VOL      0x3B // Register 59 - Left PGA Volume
#define AIC3204_RPGA_VOL      0x3C // Register 60 - Right PGA Volume
#define AIC3204_ADC_PTM       0x3D // Register 61 - ADC Power Tune Config
#define AIC3204_ADC_VOL       0x3E // Register 62 - ADC Analog Gain Control Flag 
#define AIC3204_AN_IN_CHRG    0x47 // Register 71 - Analog Input Quick Charging Config
#define AIC3204_REF_STARTUP   0x7B // Register 123 - Reference Power Up Config


#endif /* TLV320AIC3204_H_ */
