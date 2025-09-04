// Copyright 2024-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>

#include <boards_utils.h>

#if BOARD_SUPPORT_BOARD == XK_VOICE_SQ66

#include <xk_voice_sq66/board.h>
#include <platform.h>
#include "xassert.h"
#include "i2c.h"
#include "pcal6408a.h"
#include "dac3101.h"

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


//void xk_voice_sq66_core_voltage_set(const xk_voice_sq66_xcore_voltage_t voltage_setting)
//{
//    switch(voltage_setting){
//        case AUD_316_XCORE_VOLTAGE_0_925V:
//            set_pad_drive_mode(p_margin, DRIVE_BOTH);
//            p_margin <: 0; /* hard low */
//            break;
//        case AUD_316_XCORE_VOLTAGE_0_922V:
//            set_pad_drive_mode(p_margin, DRIVE_HIGH);
//            p_margin <: 0; /* pulled low */
//            break;
//        case AUD_316_XCORE_VOLTAGE_0_9V:
//            set_pad_drive_mode(p_margin, DRIVE_BOTH);
//            p_margin :> void; /* Hi-Z */
//            break;
//        case AUD_316_XCORE_VOLTAGE_0_854V:
//            set_pad_drive_mode(p_margin, DRIVE_LOW);
//            p_margin <: 1; /* pulled high */
//            break;
//        case AUD_316_XCORE_VOLTAGE_0_85V:
//            set_pad_drive_mode(p_margin, DRIVE_BOTH);
//            p_margin <: 1; /* hard high */
//            break;
//        default:
//            break;
//    }
//}

void xk_voice_sq66_board_setup(const xk_voice_sq66_config_t &config)
{

    /* "Drive high mode" - drive high for 1, non-driving for 0 */
//    set_port_drive_high(p_ctrl);

    /* Ensure we are running at nominal 0.9v */
//    xk_voice_sq66_core_voltage_set(AUD_316_XCORE_VOLTAGE_0_9V);

    /* Drive control port to turn on 3V3 and mclk direction appropriately.
     * Bits set to low will be high-z, pulled down */
//    const unsigned pll_sel_mclk_dir = (CLK_CS2100 == config.clk_mode) ? 0x00 : 0x80;
//    p_ctrl <: pll_sel_mclk_dir | 0x20;

    /* Wait for power supplies to be up and stable */
//    delay_milliseconds(10);
}


void xk_voice_sq66_i2c_master(server interface i2c_master_if i2c[1])
{
    i2c_master(i2c, 1, p_scl, p_sda, 100);
}

void xk_voice_sq66_i2c_master_exit(i2c_cli i2c)
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
void xk_voice_sq66_AudioHwInit(i2c_cli i2c, const xk_voice_sq66_config_t &config)
{
    i2c_regop_res_t result;

    // This setup is for 1.024MHz in (BCLK), PLL of 98.304MHz 24.576MHz out and fs of 16kHz or
    // or 3.072MHz BCLK, PLL of 98.304MHz 24.576MHz out and fs of 48kHz
    const unsigned PLLP = 1;
    const unsigned PLLR = 4;
    const unsigned PLLJ = (48000 == 16000) ? 24 : 8;
    const unsigned PLLD = 0;
    const unsigned NDAC = 4;
    const unsigned MDAC = (48000 == 16000) ? 6 : 4;
    const unsigned DOSR = (48000 == 16000) ? 256 : 128;

    // Wait for power supply to come up.
    printf("configure DAC\n");
    delay_milliseconds(100);

    //WriteRegs(i2c, PCAL6408A_I2C_ADDR, 1, 0x03, 0b10000011);    //RST_N, INT_N, and MUTE is input
    WriteRegs(i2c, PCAL6408A_I2C_ADDR, 1, 0x03, 0b11111111);
    //WriteRegs(i2c, PCAL6408A_I2C_ADDR, 1, 0x4F, 0b00000000);    //PushPull
    WriteRegs(i2c, PCAL6408A_I2C_ADDR, 1, 0x03, 0b11111011);
    WriteRegs(i2c, PCAL6408A_I2C_ADDR, 1, 0x01, 0b00000100);    //DAC reset is high

    delay_milliseconds(2);                               //delay for spawning AudioHwRemote2() task that uses uc_audiohw
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_PAGE_CTRL, 0x00);             // set register page to 0
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_SW_RST, 0x01);                // init sw reset, powered off PLL
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_PLL_J, PLLJ); 
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_PLL_D_LSB, PLLD & 0xff);
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_PLL_D_MSB, (PLLD & 0xff00) >> 8);
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_B_DIV_VAL, 0x80 + 1);         //bclk divider to 1
    delay_milliseconds(2);
    // Set PLL_CLKIN = BCLK (device pin), CODEC_CLKIN = PLL_CLK (generated on-chip)
    //WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_CLK_GEN_MUX, (0b01 << 2) + 0b11) == 0 &&
    //WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_CLK_GEN_MUX, (0b00 << 2) + 0b00);    // PLL_CLKIN and CODEC_CLKIN = MCLK pin
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_CLK_GEN_MUX, (0b01 << 2) + 0b11);   //based on xvf3800 config
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_PLL_P_R, 0x80 + (PLLP << 4)+ PLLR);
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_NDAC_VAL, 0x80 + NDAC);              //NDAC clock divider and power up
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_MDAC_VAL, 0x80 + MDAC);
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_DOSR_VAL_LSB, DOSR & 0xff);          // OSR to divide by 256
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_DOSR_VAL_MSB, (DOSR & 0xff00) >> 8);
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_CLKOUT_MUX, 0x04);                  //CLKOUT MUX to DAC_CLK
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_CLKOUT_M_VAL, 0x81);                // CLKOUT M divide by 1
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_GPIO1_IO, 0x10);                    // GPIO1 output from CLKOUT
    
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_CODEC_IF, 0x20);                    // i2s, 24 bit, slave mode
    
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_PAGE_CTRL, 0x01);                   // set regsiter page to 1
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_HP_DRVR, 0x14);                     // mid scale to 1.65V
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_HP_DEPOP, 0x4E);                    // de-pop. 800ms powerup, Step 4ms
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_DAC_OP_MIX, 0x44);                  // DAC output to amplifier
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_HPL_DRVR, 0x06);                    // unmute HPL. Gain = 0
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_HPR_DRVR, 0x06);                    // unmute HPR. Gain = 0
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_SPKL_DRVR, 0x0C);                   // unmute Left class D. gain = 12dB
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_SPKR_DRVR, 0x0C);                   // unmute right class D. gain = 12dB
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_HP_DRVR, 0xD4);                     // HPL, HPR powered up
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_SPK_AMP, 0xC6);                     // power up L and R class D
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_HPL_VOL_A, 0x92);                   // HPL analog volume -9dB
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_HPR_VOL_A, 0x92);                   // HPR analog volume -9dB
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_SPKL_VOL_A, 0x92);                  // left class D volume -9dB
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_SPKR_VOL_A, 0x92);                  // right class D volume -9dB
    delay_milliseconds(100);
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_PAGE_CTRL, 0x00);                   // register page 0
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_DAC_DAT_PATH, 0xD4);                // power up DAC
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_DACL_VOL_D, 0x00);                  // DAC left gain = 0dB
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_DACR_VOL_D, 0x00);                  // DAC right gain = 0dB
    WriteRegs(i2c, DAC3101_I2C_ADDR, 1, DAC3101_DAC_VOL, 0x00);                     // unmute digital volume control
    delay_milliseconds(100);
    printf("configure DAC done\n");
}

/* Configures the external audio hardware for the required sample frequency */
void xk_voice_sq66_AudioHwConfig(i2c_cli i2c, const xk_voice_sq66_config_t &config, unsigned samFreq, unsigned mClk, unsigned dsdMode, unsigned sampRes_DAC, unsigned sampRes_ADC)
{
//    sw_pll_fixed_clock(mClk);
}


void xk_voice_sq66_AudioHwShutdown(i2c_cli i2c)
{
    /* Set external I2C mux to DACs/ADCs */
//    SetI2CMux(i2c, PCA9540B_CTRL_CHAN_0);
//    WriteAllAdcRegs(i2c, PCM1865_PWR_STATE,      0x77); // Sets ADCs into powerdown.
//    WriteAllDacRegs(i2c, PCM5122_MUTE,           0x11); // Soft Mute both DACs
//    delay_milliseconds(3);  // Wait for mute to take effect. This takes 104 samples, this is 2.4ms @ 44.1kHz. So lets say 3ms to cover everything.
//    WriteAllDacRegs(i2c, PCM5122_STANDBY_PWDN,   0x10); // Request standby mode for DAC
}

void xk_voice_sq66_AudioHwPowerdown(void)
{
    /* Turn off 3v3 and 5v power supplies using board SUSPEND_N signal */
    /* Note, xcore 3v3 (3v3X) remains on */
//    p_ctrl <: 0;
}


#endif
