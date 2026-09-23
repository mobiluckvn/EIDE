#include <stdint.h>
#include <avr/interrupt.h>

/* Đếm xung từ cảm biến lưu lượng. Chạy trên ATmega328P, 8 bit. */

volatile uint32_t so_xung = 0;      /* 32 bit, ISR ghi, main đọc */
volatile uint8_t  co_tran  = 0;

ISR(INT0_vect) {
    so_xung++;
    if (so_xung == 0) co_tran = 1;
}

uint32_t doc_so_xung(void) {
    /* LỖI CÀI SẴN: đọc biến 32 bit trên MCU 8 bit mà KHÔNG chặn ngắt.
       Ngắt chen vào giữa bốn byte → giá trị lai giữa cũ và mới. */
    return so_xung;
}

void dat_lai(void) {
    so_xung = 0;
    co_tran = 0;
}

int main(void) {
    sei();
    for (;;) {
        uint32_t n = doc_so_xung();
        if (n > 1000) dat_lai();
    }
}
