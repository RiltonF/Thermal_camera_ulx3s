import board
import busio as io
import time
from adafruit_ov7670 import * 
# from adafruit_ov7670 import OV7670

def read_addr(i2c, addr):
    i2c.try_lock()
    write_buf = bytes([addr])  # Register address
    read_buf = bytearray(1)    # Buffer to store the result
    i2c.writeto_then_readfrom(0x21, write_buf, read_buf)
    print(f"[{addr}] = {read_buf(1)}")

    # i2c.writeto(0x21, bytes([addr]))
    # result = bytearray(1)
    # i2c.readfrom_into(0x21, result)
    # print(f"[{addr}] = {result}")
    i2c.unlock()

i2c = io.I2C(scl=board.GP15, sda=board.GP14);

data_pins = [getattr(board, f"GP{x}") for x in range(8)]
print(data_pins)
cam = OV7670(i2c, 
             data_pins,
             board.GP8,
             board.GP9,
             board.GP10)
cam.colorspace = OV7670_COLOR_RGB
# cam.size = OV7670_SIZE_DIV1
cam.size = OV7670_SIZE_DIV2
# cam.test_pattern = OV7670_TEST_PATTERN_SHIFTING_1
# cam.test_pattern = OV7670_TEST_PATTERN_COLOR_BAR
# cam.test_pattern = OV7670_TEST_PATTERN_COLOR_BAR_FADE
# read_addr(i2c, 0x1e)
print(cam._read_register(0x1E))
cam.flip_y= True
print(cam._read_register(0x1E))
print(cam.width)
print(cam.height)
print(cam.size)
# [print(f"{val:04x}") for val in cam.config_dump]

# with open("ov7670_rom.mem", "w") as f:
#     for val in cam.config_dump:
#         f.write(f"{val:04X}\n")

# i2c.unlock()
# read_addr(i2c, 0x1e)

# i2c.unlock()
#
# while not i2c.try_lock():
#     pass
#
# try:
#     while True:
#     # for _ in range(40):
#         print(
#             "I2C addresses found:",
#             [hex(device_address) for device_address in i2c.scan()],
#         )
#         time.sleep(2)
#
# finally:  # unlock the i2c bus when ctrl-c'ing out of the loop
#     i2c.unlock()
#
