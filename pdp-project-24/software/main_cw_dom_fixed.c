#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define CW_BASE   0x51000000
#define CW_TRIG   (*(volatile uint32_t*)(CW_BASE + 0x38))

static const uint8_t sbox[256] = {
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
};

static const uint8_t rcon[10] = {
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
};

void expand_key(uint8_t *key, uint8_t *round_keys) {
    int i;
    for (i = 0; i < 16; i++) round_keys[i] = key[i];
    for (i = 16; i < 176; i += 4) {
        uint8_t temp[4];
        temp[0] = round_keys[i-4]; temp[1] = round_keys[i-3];
        temp[2] = round_keys[i-2]; temp[3] = round_keys[i-1];
        if (i % 16 == 0) {
            uint8_t t = temp[0];
            temp[0] = sbox[temp[1]]; temp[1] = sbox[temp[2]];
            temp[2] = sbox[temp[3]]; temp[3] = sbox[t];
            temp[0] ^= rcon[(i/16)-1];
        }
        round_keys[i]   = round_keys[i-16] ^ temp[0];
        round_keys[i+1] = round_keys[i-15] ^ temp[1];
        round_keys[i+2] = round_keys[i-14] ^ temp[2];
        round_keys[i+3] = round_keys[i-13] ^ temp[3];
    }
}

static uint32_t hw_aes32esi(uint32_t rs1, uint32_t rs2, int bs) {
    register uint32_t a0_reg __asm__("a0") = rs1;
    register uint32_t a1_reg __asm__("a1") = rs2;
    register uint32_t a2_reg __asm__("a2");
    switch (bs) {
        case 0: __asm__ volatile(".word 0x22B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
        case 1: __asm__ volatile(".word 0x62B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
        case 2: __asm__ volatile(".word 0xA2B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
        default: __asm__ volatile(".word 0xE2B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
    }
    return a2_reg;
}

static uint32_t hw_aes32esmi(uint32_t rs1, uint32_t rs2, int bs) {
    register uint32_t a0_reg __asm__("a0") = rs1;
    register uint32_t a1_reg __asm__("a1") = rs2;
    register uint32_t a2_reg __asm__("a2");
    switch (bs) {
        case 0: __asm__ volatile(".word 0x26B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
        case 1: __asm__ volatile(".word 0x66B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
        case 2: __asm__ volatile(".word 0xA6B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
        default: __asm__ volatile(".word 0xE6B50613" : "=r"(a2_reg) : "r"(a0_reg), "r"(a1_reg)); break;
    }
    return a2_reg;
}

void aes128_encrypt_block(uint8_t *plaintext, uint8_t *round_keys, uint8_t *ciphertext) {
    uint32_t s0, s1, s2, s3;
    uint32_t *pt = (uint32_t *)plaintext;
    s0 = pt[0]; s1 = pt[1]; s2 = pt[2]; s3 = pt[3];
    uint32_t *rk = (uint32_t *)round_keys;

    s0 ^= rk[0]; s1 ^= rk[1]; s2 ^= rk[2]; s3 ^= rk[3];

    for (int round = 1; round < 10; round++) {
        uint32_t n0, n1, n2, n3;
        n0 = hw_aes32esmi(0,s0,0); n0 = hw_aes32esmi(n0,s1,1);
        n0 = hw_aes32esmi(n0,s2,2); n0 = hw_aes32esmi(n0,s3,3);
        n1 = hw_aes32esmi(0,s1,0); n1 = hw_aes32esmi(n1,s2,1);
        n1 = hw_aes32esmi(n1,s3,2); n1 = hw_aes32esmi(n1,s0,3);
        n2 = hw_aes32esmi(0,s2,0); n2 = hw_aes32esmi(n2,s3,1);
        n2 = hw_aes32esmi(n2,s0,2); n2 = hw_aes32esmi(n2,s1,3);
        n3 = hw_aes32esmi(0,s3,0); n3 = hw_aes32esmi(n3,s0,1);
        n3 = hw_aes32esmi(n3,s1,2); n3 = hw_aes32esmi(n3,s2,3);
        rk += 4;
        s0 = n0^rk[0]; s1 = n1^rk[1]; s2 = n2^rk[2]; s3 = n3^rk[3];
    }

    uint32_t n0, n1, n2, n3;
    n0 = hw_aes32esi(0,s0,0); n0 = hw_aes32esi(n0,s1,1);
    n0 = hw_aes32esi(n0,s2,2); n0 = hw_aes32esi(n0,s3,3);
    n1 = hw_aes32esi(0,s1,0); n1 = hw_aes32esi(n1,s2,1);
    n1 = hw_aes32esi(n1,s3,2); n1 = hw_aes32esi(n1,s0,3);
    n2 = hw_aes32esi(0,s2,0); n2 = hw_aes32esi(n2,s3,1);
    n2 = hw_aes32esi(n2,s0,2); n2 = hw_aes32esi(n2,s1,3);
    n3 = hw_aes32esi(0,s3,0); n3 = hw_aes32esi(n3,s0,1);
    n3 = hw_aes32esi(n3,s1,2); n3 = hw_aes32esi(n3,s2,3);
    rk += 4;
    n0^=rk[0]; n1^=rk[1]; n2^=rk[2]; n3^=rk[3];

    uint32_t *ct = (uint32_t *)ciphertext;
    ct[0]=n0; ct[1]=n1; ct[2]=n2; ct[3]=n3;
}

void aes128_ecb_encrypt(uint8_t *plaintext, size_t len, uint8_t *key, uint8_t *ciphertext) {
    if (len % 16 != 0) return;
    uint8_t round_keys[176];
    expand_key(key, round_keys);  // OUTSIDE trigger window
    CW_TRIG = 1;                  // trigger HIGH - only hardware execution
    for (size_t i = 0; i < len; i += 16)
        aes128_encrypt_block(&plaintext[i], round_keys, &ciphertext[i]);
    CW_TRIG = 0;                  // trigger LOW
}

#define CW_BASE   0x51000000
#define CW_START  (*(volatile uint32_t*)(CW_BASE + 0x00))
#define CW_DONE   (*(volatile uint32_t*)(CW_BASE + 0x04))
#define CW_KEY0   (*(volatile uint32_t*)(CW_BASE + 0x08))
#define CW_KEY1   (*(volatile uint32_t*)(CW_BASE + 0x0C))
#define CW_KEY2   (*(volatile uint32_t*)(CW_BASE + 0x10))
#define CW_KEY3   (*(volatile uint32_t*)(CW_BASE + 0x14))
#define CW_PT0    (*(volatile uint32_t*)(CW_BASE + 0x18))
#define CW_PT1    (*(volatile uint32_t*)(CW_BASE + 0x1C))
#define CW_PT2    (*(volatile uint32_t*)(CW_BASE + 0x20))
#define CW_PT3    (*(volatile uint32_t*)(CW_BASE + 0x24))
#define CW_CT0    (*(volatile uint32_t*)(CW_BASE + 0x28))
#define CW_CT1    (*(volatile uint32_t*)(CW_BASE + 0x2C))
#define CW_CT2    (*(volatile uint32_t*)(CW_BASE + 0x30))
#define CW_CT3    (*(volatile uint32_t*)(CW_BASE + 0x34))
#define CW_TRIG   (*(volatile uint32_t*)(CW_BASE + 0x38))

int main(void) {
    uint8_t key[16], plaintext[16], ciphertext[16];
    uint32_t k[4], p[4], c[4];
    while(1) {
        while(CW_START == 0);
        k[0]=CW_KEY0; k[1]=CW_KEY1; k[2]=CW_KEY2; k[3]=CW_KEY3;
        p[0]=CW_PT0;  p[1]=CW_PT1;  p[2]=CW_PT2;  p[3]=CW_PT3;
        memcpy(key, k, 16);
        memcpy(plaintext, p, 16);
        aes128_ecb_encrypt(plaintext, 16, key, ciphertext);
        for(int i=0;i<4;i++){
            c[i] = (uint32_t)ciphertext[i*4]        |
                   ((uint32_t)ciphertext[i*4+1]<<8) |
                   ((uint32_t)ciphertext[i*4+2]<<16)|
                   ((uint32_t)ciphertext[i*4+3]<<24);
        }
        CW_CT0=c[0]; CW_CT1=c[1]; CW_CT2=c[2]; CW_CT3=c[3];
        CW_DONE = 1;
    }
    return 0;
}
