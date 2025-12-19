#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
5镜运动控制协议 - CRC16计算工具

支持：
1. 字符串指令CRC计算（输出4位十六进制大写字符）
2. 二进制数据CRC计算（输出大端序字节）
"""

def crc16(data):
    """
    CRC-16-ANSI/IBM 算法
    多项式: 0x8005
    初始值: 0xFFFF
    结果异或值: 0x0000
    输入反转: 是
    输出反转: 是
    """
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc = crc >> 1
    return crc


def calc_string_crc(command_str):
    """
    计算字符串指令的CRC
    
    Args:
        command_str: 不含帧头$和帧尾;的指令内容
        
    Returns:
        4位十六进制大写字符串
    """
    data = command_str.encode('ascii')
    crc = crc16(data)
    return f'{crc:04X}'


def calc_binary_crc(data_bytes):
    """
    计算二进制数据的CRC（大端序）
    
    Args:
        data_bytes: 字节数据（bytes或bytearray）
        
    Returns:
        (高字节, 低字节) 元组
    """
    crc = crc16(data_bytes)
    high_byte = (crc >> 8) & 0xFF
    low_byte = crc & 0xFF
    return (high_byte, low_byte)


def main():
    """交互式计算CRC"""
    print('='*70)
    print('5镜运动控制协议 - CRC16计算工具')
    print('='*70)
    print()
    
    while True:
        print('选择模式：')
        print('  1 - 字符串指令CRC（输出如：A3F2）')
        print('  2 - 二进制数据CRC（输出如：0xA3 0xF2）')
        print('  3 - 批量计算示例')
        print('  q - 退出')
        print()
        
        choice = input('请选择 [1/2/3/q]: ').strip()
        
        if choice == 'q':
            print('退出程序')
            break
            
        elif choice == '1':
            print()
            print('输入指令内容（不含 $ 和 ;）:')
            print('例如: MOTOR,C1,M7,STOP')
            cmd = input('> ').strip()
            
            if cmd:
                try:
                    crc_str = calc_string_crc(cmd)
                    print()
                    print(f'指令: ${cmd};')
                    print(f'CRC16: {crc_str}')
                    print(f'完整指令: ${cmd};{crc_str}')
                    print()
                except Exception as e:
                    print(f'错误: {e}')
                    print()
            
        elif choice == '2':
            print()
            print('输入十六进制数据（空格分隔）:')
            print('例如: 18 00 7A 12 00 ... (LEN + DATA)')
            hex_str = input('> ').strip()
            
            if hex_str:
                try:
                    data = bytes.fromhex(hex_str)
                    high, low = calc_binary_crc(data)
                    crc_value = (high << 8) | low
                    print()
                    print(f'数据: {" ".join(f"{b:02X}" for b in data)}')
                    print(f'CRC16: 0x{crc_value:04X}')
                    print(f'大端序字节: 0x{high:02X} 0x{low:02X}')
                    print(f'完整帧: AA 55 {hex_str} {high:02X} {low:02X}')
                    print()
                except Exception as e:
                    print(f'错误: {e}')
                    print()
                    
        elif choice == '3':
            print()
            print('常用指令CRC值参考：')
            print('-'*70)
            
            examples = [
                'MOTOR,C1,M7,STOP',
                'MOTOR,C1,M7,MOVE_REL,10.5',
                'MOTOR,C1,M7,HOME',
                'MOTOR,C1,ALL,STOP',
                'GRATING,G1,HOME',
                'GRATING,G1,GET_STATUS',
                'SYSTEM,HELLO',
                'SYSTEM,GET_INFO',
                'SYSTEM,INIT',
                'ACK',
            ]
            
            for cmd in examples:
                crc_str = calc_string_crc(cmd)
                print(f'${cmd};{crc_str}')
            
            print('-'*70)
            print()
        
        else:
            print('无效选择，请重新输入')
            print()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('\n\n程序被中断')
    except Exception as e:
        print(f'\n错误: {e}')

