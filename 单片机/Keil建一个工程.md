
# Keil 新建 STM32 工程：从零到能下程序

> 前置：已安装 **Keil MDK-ARM**、对应系列 **DFP 设备包**、**ST-LINK 驱动**（建议装 `STM32CubeProgrammer` 时顺便装）。

## 0. 一次性准备（只需做一次）

- 打开 **Keil → File → Pack Installer**
    
    - 左侧选 **STMicroelectronics**，安装你的系列 **DFP**（例：`STM32F1xx_DFP`/`F4xx_DFP`/`H7xx_DFP`…）
    - 至少确保：**CMSIS: CORE**、**Device: Startup** 安装好了
    ![[Pasted image 20251013011103.png]]
- 用 **STM32CubeProgrammer** 连接一次 ST-LINK，能看到 **Target Voltage** 并升级固件
    

---

**第一步：新建工程**

- 打开 Keil MDK。
- 点击菜单栏 Project -> New µVision Project...。
- 选择一个空文件夹用于存放工程，输入工程名（例如 MyProject），点击“保存”。

**第二步：选择目标芯片**

- 在弹出的 Select Device for Target 'Target 1'... 窗口中，找到并选择你的 MCU 型号。例如，选择 STMicroelectronics -> STM32F1 Series -> STM32F103C8。
- 点击 OK。

![[Pasted image 20251013013844.png]]

**第三步：管理运行时环境 (Manage Run-Time Environment)**

- 这个窗口是 Keil 5 的核心功能之一，用于管理软件包 (Software Packs)。
    
- 对于一个从零开始的工程，我们先进行最基础的配置：
    
    - 展开 CMSIS，勾选 CORE。这是ARM Cortex-M内核的通用核心接口文件，**必须勾选**。
        
    - 展开 Device，勾选 Startup。这是芯片的启动文件，**必须勾选**。它负责初始化堆栈指针、中断向量表，并最终调用 main 函数。
        
- 点击 OK。
![[Pasted image 20251013020135.png]]
![[Pasted image 20251013020255.png]]
**空项目 + core + startup** 最基本会有这几个文件：

- `startup_stm32f10x.s`
- `system_stm32f10x.c`
- `RTE_Components.h`
- `scatter file (.sct)`


==**如果不配置管理运行时环境 (Manage Run-Time Environment)**==
项目是一个空的
![[Pasted image 20251013102529.png]]
这样需要添加一些工程的必要文件
- **1.stm32的启动文件**，stm32的程序就是从这些启动文件开始执行的
![[Pasted image 20251013102713.png]]
![[Pasted image 20251013113104.png]]
> 在项目中新建一个文件夹，比如叫Start，然后把这些文件放到该目录下
![[Pasted image 20251013113125.png]]

## 2. 工程里“必备文件”到底有哪些？

> 这几样是**任何方式**都离不开的（名字随系列不同而不同）：

- `startup_stm32xxxx.s`  
    **启动文件**，中断向量表 + 复位入口，DFP 会自动提供
    
- `system_stm32xxxx.c`  
    **系统初始化**（SystemInit）+ `SystemCoreClock` 维护等
    
- `stm32xxxx.h`（以及 `stm32xxxx_hal_conf.h` / `stm32xxxx_ll_*` 头文件）  
    **芯片寄存器定义 / HAL/LL 配置头**
    
- `core_cm?.h`（CMSIS 核心头）  
    **Cortex-M** 内核通用定义
    
- （Keil）**链接/装载信息**  
    使用“**Options → Target 的 IROM/IRAM 填写**”，Keil 会生成默认 scatter；也可以自带 `.sct` 文件
    

> ✅ 结论：**DFP 安好 + 在 MRTE 里按需要勾选**，这些文件 Keil 会自动加入，无需手动找文件到处拷。

## 3. 三种开发方式分别要怎么勾、怎么写？

> 下面每种都给出：**MRTE 勾选 → 需要的文件/宏 → 最小代码 → 小坑**

### A）裸寄存器（Register，最轻量）

**MRTE 勾选：**

- `CMSIS → CORE`（必选）
    
- `Device → Startup`（必选）
    
- **不要**勾 HAL/LL/SPL
    

**需要的宏（Options → C/C++ → Define）：**

- 器件宏：如 `STM32F103xB` / `STM32F401xE` / `STM32H743xx`（DFP 通常自动加上）
    
- （可选）`HSE_VALUE=8000000` 等实际晶振值（不写也能跑 HSI）
    

**最小代码（示例：F1 PC13 点灯）**：
```
#include "stm32f10x.h"
int main(void){
  RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;
  GPIOC->CRH &= ~(GPIO_CRH_MODE13 | GPIO_CRH_CNF13);
  GPIOC->CRH |=  (0x2 << GPIO_CRH_MODE13_Pos); // 2MHz 推挽
  while(1){
    GPIOC->BSRR = (1U<<13);
    for(volatile int i=0;i<500000;i++);
    GPIOC->BRR  = (1U<<13);
    for(volatile int i=0;i<500000;i++);
  }
}

```

**小坑：**

- 时钟树、外设复位/使能要全靠自己配，**最容易忘 RCC 时钟**
- F1/F4/F7/H7 **寄存器名/时钟域不同**，抄代码要对应系列手册
---

### B）HAL / LL（官方主推，推荐）

**两种入口：**

- **纯 Keil 勾选法**（不依赖 CubeMX）
    
- **用 CubeMX 生成 MDK-ARM 工程**（最省心，连时钟/引脚都配好）
    

**MRTE 勾选（纯 Keil 法）：**

- `CMSIS → CORE`（必）
    
- `Device → Startup`（必）
    
- `STM32Cube Framework → HAL`（常用）或 `→ LL`（更轻量）
    
    - 用哪个外设就勾对应 HAL/LL 组件（GPIO/UART/I2C/SPI/ADC…）
        

**需要的宏：**

- `USE_HAL_DRIVER`（勾 HAL 时自动加）
    
- 器件宏：`STM32F401xE` 等（自动）
    
- （H7/F7 等有 Cache 的）注意 `ART/Cache`、`DCache` 与 `DMA` 一致性问题
    

**最小代码（HAL 版）**：































# 2. 四种开发方式是啥？

## A. 裸寄存器（Register / 直接寄存器）

- **怎么写**：直接改寄存器位，比如 `GPIOC->CRH = ...`、`RCC->APB2ENR |= ...`
- **依赖**：最少，只用 **CMSIS 头文件**（随 Keil DFP 有）。
- **优点**：体积小、可控性最高、性能最好、理解底层最快。
- **缺点**：上手慢、可读性差、可移植性差、后期维护成本高、易踩坑（时钟/位定义/时序）。
- **适合**：资源极小的芯片、**竞赛/极限优化**、必须完全掌握外设细节的场景。
    

## B. 标准外设库（SPL, Standard Peripheral Library）—“老库”

- **怎么写**：`GPIO_Init()`、`USART_Init()` 这类函数（F1/F4 时代的老接口）。
    
- **依赖**：需要装对应“**STM32Fxxx SPL**”（现在基本被 HAL 取代）。
    
- **优点**：比裸寄存器好读；当年资料多。
    
- **缺点**：**已停止更新**，新型号没有；与 HAL 生态不兼容；中间件支持弱。
    
- **适合**：**维护旧项目** 或 学习老资料；**新项目不建议**。
    

## C. HAL / LL（Cube 家族，官方主推）

- **HAL（Hardware Abstraction Layer）**：高抽象，函数多，配置靠 **CubeMX** 自动生成。
    
- **LL（Low-Layer）**：更贴近寄存器，**函数即是寄存器字段**，开销小于 HAL。
    
- **依赖**：在 Keil 的 **Pack Installer** 勾 **STM32Cube HAL/LL** 组件，或用 **CubeMX 生成 MDK 工程**。
    
- **优点**：官方维护、新型号全覆盖、**和中间件（USB、lwIP、FreeRTOS…）配套**、示例齐。
    
- **缺点**：HAL 代码量大、效率低于裸寄存器/LL；学习 HAL 的“套路”也要时间。
    
- **适合**：**90% 新项目**；追稳定、追效率可**HAL+LL 混用**。
    

## D. 混合用法（推荐的“工程思路”）

- **思路**：大部分用 **HAL** 快速带起项目；**关键路径**（中断、DMA、GPIO 快速翻转、时序严苛）用 **LL** 或 **寄存器**微调。
    
- **现实可行**：官方示例也经常 HAL+LL 同时存在。
    
---

## 3）怎么在 Keil 里“选”一种方式？

- **裸寄存器**：只选 **CMSIS:Core**、**Device:Startup**，自己写所有寄存器代码与启动配置。
    
- **SPL**：装老的 SPL 包（现在不推荐）；工程里包含 SPL 源码，按它的 `*_Init()` 调。
    
- **HAL/LL**（推荐）：
    
    1. 在 **Pack Installer** 勾系列的 **Device DFP**、**CMSIS:Core**；
        
    2. 勾 **STM32Cube HAL**（或 LL），需要哪个外设就勾对应组件；
        
    3. 或者直接用 **STM32CubeMX → 选择 MDK-ARM 生成工程**，Keil 打开 `.uvprojx` 即可。
        

---

## 4）优缺点评价表（选型就看这张）
| 方式        | 上手速度 | 可读性/维护 | 代码体积  | 性能实时性 | 生态/示例 | 适用场景           |
| --------- | ---- | ------ | ----- | ----- | ----- | -------------- |
| 裸寄存器      | ★    | ★      | ★★★★★ | ★★★★★ | ★     | 极限优化、超小固件、底层学习 |
| SPL（老库）   | ★★   | ★★☆    | ★★★   | ★★★   | ★★    | 维护旧项目          |
| HAL       | ★★★★ | ★★★★   | ★★    | ★★★   | ★★★★★ | 新项目/中间件/快速落地   |
| LL        | ★★★  | ★★★    | ★★★★  | ★★★★  | ★★★★  | 对性能/时序敏感的模块    |
| HAL+LL 混合 | ★★★★ | ★★★★   | ★★★   | ★★★★  | ★★★★★ | **推荐的工程实践**    |
## 5）怎么“合理搭配”？

- **默认**用 HAL：时钟、GPIO、UART、I2C、SPI、USB、中间件（FatFs、lwIP、USB-CDC/HID）都很顺手。
    
- **关键路径**（高频中断、快速 GPIO 翻转、捕获比较、DMA 硬件触发链路）用 **LL/寄存器**微调。
    
- **不要同时引入 SPL 与 HAL**（会冲突）。
    
- HAL 下也能直接改寄存器，但**注意不要破坏 HAL 已经配置好的状态**（比如时钟域、DMA 链接）。