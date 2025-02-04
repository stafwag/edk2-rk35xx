/** @file
*  PCIe Controller devices.
*
*  Copyright (c) 2022, Rockchip Inc.
*  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include "AcpiTables.h"

// PCIe 3x4
Device (PCI0) {
	Name (_HID, "PNP0A08") // PCI Express Root Bridge
	Name (_CID, "PNP0A03") // Compatible PCI Root Bridge
	Name (_CCA, Zero)
	Name (_SEG, Zero)      // Segment of this Root complex
	Name (_BBN, Zero)      // Base Bus Number

	Name (_PRT, Package() { //legacy的支持需要route到不同的SPI，目前无法使用。。。
		Package (4) { 0x0FFFF, 0, Zero, 292 },
		Package (4) { 0x0FFFF, 1, Zero, 292 },
		Package (4) { 0x0FFFF, 2, Zero, 292 },
		Package (4) { 0x0FFFF, 3, Zero, 292 }
	})

	Method (_CRS, 0, Serialized) { // Root complex resources
		Name (RBUF, ResourceTemplate () {
		WordBusNumber (ResourceProducer, MinFixed, MaxFixed, PosDecode, // Bus numbers assigned to this root
			0,    // Granularity
			0,    // AddressMinimum - Minimum Bus Number
			0xf,   // AddressMaximum - Maximum Bus Number
			0,    // AddressTranslation - Set to 0
			16,    // RangeLength - Number of Busses
		)

		DWordMemory (ResourceProducer, PosDecode, MinFixed, MaxFixed, NonCacheable, ReadWrite, // 32-bit BAR Windows
			0x00000000,   // Granularity
			FixedPcdGet32 (PcdPcieRootPort3x4MemBaseAddress),   // Range Minimum
			0xF0FFFFFF,   // Range Maximum
			0x00000000,   // Translation Offset
			FixedPcdGet32 (PcdPcieRootPort3x4MemSize),   // Length
		)

		QWordMemory (ResourceProducer, PosDecode, MinFixed, MaxFixed, NonCacheable, ReadWrite, // 64-bit BAR Windows
			0x0000000000000000,   // Granularity
			FixedPcdGet64 (PcdPcieRootPort3x4MemBaseAddress64),   // Range Minimum
			0x000000093fffffff,   // Range Maximum
			0x0000000000000000,   // Translation Offset
			FixedPcdGet64 (PcdPcieRootPort3x4MemSize64),   // Length
		)

		QWordIO (ResourceProducer, MinFixed, MaxFixed, PosDecode, EntireRange,  // IO BAR Windows
			0,                    // Granularity
			0x0000,               // Range Minimum
			0xFFFF,               // Range Maximum
			FixedPcdGet32 (PcdPcieRootPort3x4IoBaseAddress),   		  // Translation Offset
			FixedPcdGet32 (PcdPcieRootPort3x4IoSize),              // Length
		)
		})
		return (RBUF)
	}

	// Method (_CBA, 0, NotSerialized) {
	// 	return (0x900000000) //指定外设ECAM空间,acpi_pci_root_get_mcfg_addr拿到的是这个，且不能和Mcfg里面的地址一样
	// }

	Device (RES0) {
        Name (_HID, "PNP0C02")
		Name (_CRS, ResourceTemplate (){
			Memory32Fixed (ReadWrite, 0xf5000000 , 0x400000) //DBI for accessing RC config base address
			// 64-bit PCIe ECAM window
			QWordMemory (ResourceProducer, PosDecode, MinFixed, MaxFixed, NonCacheable, ReadWrite,
			0x0000000000000000,    // Granularity
			0x0000000900000000,    // Range Minimum
			0x0000000900ffffff,    // Range Maximum
			0x0000000000000000,    // Translation Offset
			0x0000000001000000,    // Length
		)
		})
	}

	// OS Control Handoff
	Name(SUPP, Zero) // PCI _OSC Support Field value
	Name(CTRL, Zero) // PCI _OSC Control Field value

	// See [1] 6.2.10, [2] 4.5
	Method(_OSC,4) {
		// Note, This code is very similar to the code in the PCIe firmware
		// specification which can be used as a reference
		// Check for proper UUID
		If(LEqual(Arg0,ToUUID("33DB4D5B-1FF7-401C-9657-7441C03DD766"))) {
		// Create DWord-adressable fields from the Capabilities Buffer
		CreateDWordField(Arg3,0,CDW1)
		CreateDWordField(Arg3,4,CDW2)
		CreateDWordField(Arg3,8,CDW3)
		// Save Capabilities DWord2 & 3
		Store(CDW2,SUPP)
		Store(CDW3,CTRL)
		// Mask out Native HotPlug
		And(CTRL,0x1E,CTRL)
		// Always allow native PME, AER (no dependencies)
		// Never allow SHPC (no SHPC controller in this system)
		And(CTRL,0x1D,CTRL)

		If(LNotEqual(Arg1,One)) { // Unknown revision
			Or(CDW1,0x08,CDW1)
		}

		If(LNotEqual(CDW3,CTRL)) {  // Capabilities bits were masked
			Or(CDW1,0x10,CDW1)
		}
		// Update DWORD3 in the buffer
		Store(CTRL,CDW3)
		Return(Arg3)
		} Else {
		Or(CDW1,4,CDW1) // Unrecognized UUID
		Return(Arg3)
		}
	} // End _OSC
}
