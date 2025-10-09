// Copyright 2024-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>

#include <boards_utils.h>

#if BOARD_SUPPORT_BOARD == CSL_HDMI_DONGLE

#include <csl_hdmi_dongle/board.h>
#include <platform.h>
#include "xassert.h"
#include "i2c.h"

#include "tlv320aic3204.h"

extern "C" {
    #include "sw_pll.h"
}

#ifndef I2S_LOOPBACK
#define I2S_LOOPBACK             (0)
#endif

// reduce verbosity
typedef client interface i2c_master_if i2c_cli;

/* All on tile[0] */
port p_scl = PORT_I2C_SCL;
port p_sda = PORT_I2C_SDA;

out port p_ctrl = PORT_GPO_CTRL;        // [5] - MUTE; [4] - DAC_RST
#define PIN_MUTE    5       
#define PIN_DAC_RST 4

#define DRIVE_LOW_MUTE_PIN  ( (~(1 << PIN_MUTE)) & (1 << PIN_MUTE))
#define DRIVE_HIGH_MUTE_PIN (1 << PIN_MUTE)
#define DRIVE_LOW_DAC_RST_PIN  ( (~(1 << PIN_DAC_RST)) & (1 << PIN_DAC_RST))
#define DRIVE_HIGH_DAC_RST_PIN (1 << PIN_DAC_RST)

#define CTRL_WAKE_UP_DAC_N_MUTE  DRIVE_HIGH_DAC_RST_PIN | DRIVE_LOW_MUTE_PIN   // 0b00010000
#define CTRL_MUTE                DRIVE_HIGH_DAC_RST_PIN | DRIVE_LOW_MUTE_PIN   // 0b00010000
#define CTRL_UNMUTE              DRIVE_HIGH_DAC_RST_PIN | DRIVE_HIGH_MUTE_PIN  // 0b00110000
#define CTRL_SHUTDOWN            DRIVE_LOW_DAC_RST_PIN | DRIVE_LOW_MUTE_PIN    // 0b00000000

/*out port p_ctrl = PORT_CTRL;*/                /* p_ctrl:
                                             * [0:4] - Unused
                                             * [5]   - SUSPEND_N
                                             * [6]   - EXT_PLL_SEL (CS2100:0, SI: 1)
                                             * [7]   - MCLK_DIR    (Out:0, In: 1)
                                             */

/*on tile[0]: port p_margin = XS1_PORT_1G;*/     /* CORE_POWER_MARGIN:   Driven 0:   0.925v
                                              *                      Pull down:  0.922v
                                              *                      High-z:     0.9v
                                              *                      Pull-up:    0.854v
                                              *                      Driven 1:   0.85v
                                              */

/* Macro to enable the drive mode (open drain/source or complementary) */
#define set_pad_drive_mode(port, mode)  {__asm__ __volatile__ ("setc res[%0], %1": : "r" (port) , "r" ((mode << _MODE_SHIFT) | PAD_DRIVE_MODE));}
/* Pad control defines */
#define PAD_DRIVE_MODE  0x0003
#define DRIVE_BOTH      0x0
#define DRIVE_HIGH      0x1
#define DRIVE_LOW       0x2
#define _MODE_SHIFT     0

void bsp_board_setup(const bsp_config_t &config)
{
    // wake up DAC and MUTE
    p_ctrl <: CTRL_WAKE_UP_DAC_N_MUTE;
    delay_milliseconds(100);
    p_ctrl <: CTRL_UNMUTE;
    return;
}

void bsp_dac_unmute(void)
{
    p_ctrl <: CTRL_UNMUTE;
    delay_milliseconds(10);
    return;
}

void bsp_dac_mute(void)
{
    p_ctrl <: CTRL_MUTE;
    delay_milliseconds(10);
    return;
}


void bsp_i2c_master(server interface i2c_master_if i2c[1])
{
    i2c_master(i2c, 1, p_scl, p_sda, 100);
}

void bsp_i2c_master_exit(i2c_cli i2c)
{
    i2c.shutdown();
}

/* Working around not being able to extend an unsafe interface (Bugzilla #18670)*/
static i2c_regop_res_t i2c_reg_write(i2c_cli i2c, uint8_t device_addr, uint8_t reg, uint8_t data)
{
    uint8_t a_data[2] = {reg, data};
    size_t n;

    unsafe
    {
        i2c.write(device_addr, a_data, 2, n, 1);
    }

    if (n == 0)
    {
        return I2C_REGOP_DEVICE_NACK;
    }
    if (n < 2)
    {
        return I2C_REGOP_INCOMPLETE;
    }

    return I2C_REGOP_SUCCESS;
}

static uint8_t i2c_reg_read(i2c_cli i2c, uint8_t device_addr, uint8_t reg, i2c_regop_res_t &result)
{
    uint8_t a_reg[1] = {reg};
    uint8_t data[1] = {0};
    size_t n;
    i2c_res_t res;

    unsafe
    {
        res = i2c.write(device_addr, a_reg, 1, n, 0);

        if (n != 1)
        {
            result = I2C_REGOP_DEVICE_NACK;
            i2c.send_stop_bit();
            return 0;
        }

        res = i2c.read(device_addr, data, 1, 1);
    }

    if (res == I2C_ACK)
    {
        result = I2C_REGOP_SUCCESS;
    }
    else
    {
        result = I2C_REGOP_DEVICE_NACK;
    }
    return data[0];
}

/* The number of timer ticks to wait for the audio PLL to lock */
/* CS2100 lists typical lock time as 100 * input period */
#define AUDIO_PLL_LOCK_DELAY        (40000000)

#undef UNSAFE


static void WriteRegs(i2c_cli i2c, int deviceAddr, int numDevices, int regAddr, int regData)
{
    i2c_regop_res_t result;

    for(int i = deviceAddr; i < (deviceAddr + numDevices); i++)
    {
        unsafe
        {
            result = i2c_reg_write(i2c, i, regAddr, regData);
        }
        assert(result == I2C_REGOP_SUCCESS && msg("I2C write reg failed"));
    }
}

/* Configures the external audio hardware at startup */
void bsp_AudioHwInit(i2c_cli i2c, const bsp_config_t &config)
{
    // hardware DAC
    // Wait for power supply to come up.
    delay_milliseconds(100);
    i2c_regop_res_t result;

    // Wait for power supply to come up.
    printf("configure DAC\n");
    delay_milliseconds(100);

    delay_milliseconds(2);                               
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PAGE_CTRL, 0x00);             // set register page to 0
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_SW_RST, 0x01);                // init sw reset, powered off PLL
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_NDAC, 0x81); 
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_MDAC, 0x84);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_NADC, 0x81);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_MADC, 0x84);         
    delay_milliseconds(2);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_DOSR_LSB, 0x80);   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_AOSR, 0x80);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_CODEC_IF, 0x20);              
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_DAC_SIG_PROC, 0x01);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_ADC_SIG_PROC, 0x01);          
    
    // Select page 1
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PAGE_CTRL, 0x01);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_LDO_CTRL, 0x09);       
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PWR_CFG, 0x08);        
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_LDO_CTRL, 0x01);       
    
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_CM_CTRL, 0x33);        
    
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PLAY_CFG1, 0x00);      
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PLAY_CFG2, 0x00);      
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_ADC_PTM, 0x00);        
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_AN_IN_CHRG, 0x31);     
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_REF_STARTUP, 0x01);    
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_HP_START, 0x25);       
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_HPL_ROUTE, 0x08);      
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_HPR_ROUTE, 0x08);      
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x0e, 0x08);                   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x0f, 0x08);                   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x12, 0x3a);                   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x13, 0x3a);                   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_LPGA_P_ROUTE, 0x20);   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_LPGA_N_ROUTE, 0x20);   
//    delay_milliseconds(100);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_RPGA_P_ROUTE, 0x80);   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_RPGA_N_ROUTE, 0x20);   
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_HPL_GAIN, 0x06);       
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_HPR_GAIN, 0x06);       
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_LPGA_VOL, 0x00);       
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_RPGA_VOL, 0x00);       
//    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_OP_PWR_CTRL, 0x30);    
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_OP_PWR_CTRL, 0x0C);    
    
    delay_milliseconds(10);

    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PAGE_CTRL, 0x00);      
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_DAC_CH_SET1, 0xd4);    
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_ADC_CH_SET, 0xc0);     
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_DAC_CH_SET2, 0x00);    
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_ADC_FGA_MUTE, 0x00);   
    
    // adc_2ch_48k_high_performance
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PAGE_CTRL, 0x01);      
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x47, 0x32);                
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x7b, 0x01); 
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x33, 0x60);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x37, 0x80);
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x39, 0x20);         
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x3c, 40);           
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, AIC3204_PAGE_CTRL, 0x00); 
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x51, 0xc0); 
    WriteRegs(i2c, AIC3204_I2C_DEVICE_ADDR, 1, 0x52, 0x00);

    printf("configure DAC done\n");
}

/* Configures the external audio hardware for the required sample frequency */
void bsp_AudioHwConfig(i2c_cli i2c, const bsp_config_t &config, unsigned samFreq, unsigned mClk, unsigned dsdMode, unsigned sampRes_DAC, unsigned sampRes_ADC)
{
//    sw_pll_fixed_clock(mClk);
}


void bsp_AudioHwShutdown(i2c_cli i2c)
{
    /* Set external I2C mux to DACs/ADCs */
}

void bsp_AudioHwPowerdown(void)
{
    /* Turn off 3v3 and 5v power supplies using board SUSPEND_N signal */
    /* Note, xcore 3v3 (3v3X) remains on */
//    p_ctrl <: 0;
}


#endif
