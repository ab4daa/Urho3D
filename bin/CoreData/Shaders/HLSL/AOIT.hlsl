#line 20000
/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2017 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
/////////////////////////////////////////////////////////////////////////////////////////////

#ifndef H_AOIT
#define H_AOIT

typedef uint COLOR;


//////////////////////////////////////////////
// Defines
//////////////////////////////////////////////

#ifdef aoit_node_count
#define AOIT_NODE_COUNT	 aoit_node_count
#endif


#ifndef AOIT_NODE_COUNT 
#define AOIT_NODE_COUNT			(4)
#endif

#if AOIT_NODE_COUNT == 2
#define AOIT_RT_COUNT			(1)
#else
#define AOIT_RT_COUNT			(AOIT_NODE_COUNT / 4)
#endif

// Forces compression to only work on the second half of the nodes (cheaper and better IQ in some cases)

#if AOIT_NODE_COUNT >= 8
#define AOIT_DONT_COMPRESS_FIRST_HALF 
#endif

//#define AOIT_EARLY_Z_CULL

#define AOIT_TILED_ADDRESSING

#define dopso

// Various constants used by the algorithm
#define AOIT_EMPTY_NODE_DEPTH   (3.40282E38)
#define AOIT_TRANS_BIT_COUNT    (8)
#define AOIT_MAX_UNNORM_TRANS   ((1 << AOIT_TRANS_BIT_COUNT) - 1)
#define AOIT_TRANS_MASK         (0xFFFFFFFF - (uint)AOIT_MAX_UNNORM_TRANS)

void UnpackRGBA16(in uint rg, in uint b_trans, out float3 color, out float trans)
{
	uint3 p = uint3(rg >> 16UL,
		rg & 0xFFFFUL,
		b_trans >> 16UL);
	color = ((float3)p) / 65535;
	trans = float(b_trans & 0xFFFFUL);
}

void PackRGBA16(in float3 color, in float trans, out uint rg, out uint b_trans)
{
	uint3 u = (uint3)(saturate(color) * 65535 + 0.5);
	rg = (u.x << 16UL) | (u.y & 0xFFFFUL);
	b_trans = (u.z << 16UL) | (uint(trans) & 0xFFFFUL);
}

float UnpackUnnormAlpha(COLOR packedInput)
{

	return (float)(packedInput >> 24UL);
}

float3 UnpackRGB(COLOR packedInput)
{
	float3 unpackedOutput;
	uint3 p = uint3((packedInput & 0xFFUL),
		(packedInput >> 8UL) & 0xFFUL,
		(packedInput >> 16UL) & 0xFFUL);

	unpackedOutput = ((float3)p) / 255;
	return unpackedOutput;
}



COLOR PackRGB(float3 unpackedInput)
{
	uint3 u = (uint3)(saturate(unpackedInput) * 255 + 0.5);
	uint  packedOutput = (u.z << 16UL) | (u.y << 8UL) | u.x;
	return packedOutput;
}

COLOR PackRGBA(float4 unpackedInput)
{
	uint4 u = (uint4)(saturate(unpackedInput) * 255 + 0.5);
	uint  packedOutput = (u.w << 24UL) | (u.z << 16UL) | (u.y << 8UL) | u.x;
	return packedOutput;
}

float4 UnpackRGBA(COLOR packedInput)
{
	float4 unpackedOutput;
	uint4 p = uint4((packedInput & 0xFFUL),
		(packedInput >> 8UL) & 0xFFUL,
		(packedInput >> 16UL) & 0xFFUL,
		(packedInput >> 24UL));

	unpackedOutput = ((float4)p) / 255;
	return unpackedOutput;
}






//////////////////////////////////////////////
// Structs
//////////////////////////////////////////////

struct AOITCtrlSurface
{
	bool  clear;
	bool  trans_updated;
	float last_trans;
};

struct AOITSPData
{
	float4 depth[AOIT_RT_COUNT];
	uint4  color[AOIT_RT_COUNT];
};

struct AOITSPDepthData
{
	float depth[AOIT_NODE_COUNT];
};

struct AOITSPColorData
{
	float3 color[AOIT_NODE_COUNT];
	float trans[AOIT_NODE_COUNT];
};

struct ATSPNode
{
    float  depth;
    float  trans;
    float3 color;
};

//////////////////////////////////////////////
// Resources
//////////////////////////////////////////////


#if AOIT_NODE_COUNT == 8
#define _AOITSPDepthDataUAV g8AOITSPDepthDataUAV
#define _AOITSPColorDataUAV g8AOITSPColorDataUAV
#define _AOITSPColorDataSRV g8AOITSPColorDataSRV
#define _AOITSPDepthDataSRV g8AOITSPDepthDataSRV
#else
#define _AOITSPDepthDataUAV gAOITSPDepthDataUAV
#define _AOITSPColorDataUAV gAOITSPColorDataUAV
#define _AOITSPColorDataSRV gAOITSPColorDataSRV
#define _AOITSPDepthDataSRV gAOITSPDepthDataSRV
#endif


// Since there's no reflection on the cpp side for these, set registers explicitly - don't change them, this is the expected order
#ifdef dopso
RasterizerOrderedTexture2D<uint> gAOITSPClearMaskUAV        : register( u0 );
#else
RWTexture2D<uint> gAOITSPClearMaskUAV        : register(u0);
#endif
//RWStructuredBuffer<AOITSPDepthData> _AOITSPDepthDataUAV     : register( u1 );
//RWStructuredBuffer<AOITSPColorData> _AOITSPColorDataUAV     : register( u2 );
RasterizerOrderedStructuredBuffer<AOITSPDepthData> _AOITSPDepthDataUAV     : register( u1 );
RasterizerOrderedStructuredBuffer<AOITSPColorData> _AOITSPColorDataUAV     : register( u2 );

Texture2D<uint> gAOITSPClearMaskSRV                         : register( t0 );
StructuredBuffer<AOITSPDepthData> _AOITSPDepthDataSRV       : register( t1 );
StructuredBuffer<AOITSPColorData> _AOITSPColorDataSRV       : register( t2 );


//////////////////////////////////////////////
// Main AOIT fragment insertion code
//////////////////////////////////////////////

//////////////////////////////////////////////
// Main AOIT fragment insertion code
//////////////////////////////////////////////

void AOITSPInsertFragment(in float  fragmentDepth,
                          in float  fragmentTrans,
                          in float3 fragmentColor,
                          inout ATSPNode nodeArray[AOIT_NODE_COUNT],
						  inout AOITCtrlSurface ctlSurface)
{	
    int i, j;

    float  depth[AOIT_NODE_COUNT + 1];	
    float  trans[AOIT_NODE_COUNT + 1];	 
    float3   color[AOIT_NODE_COUNT + 1];	 

    ///////////////////////////////////////////////////
    // Unpack AOIT data
    ///////////////////////////////////////////////////                   
    [unroll] for (i = 0; i < AOIT_NODE_COUNT; ++i) {
        depth[i] = nodeArray[i].depth;
        trans[i] = nodeArray[i].trans;
        color[i] = nodeArray[i].color;
    }	
	
    // Find insertion index 
    int index = 0;
    float prevTrans = 1;
    [unroll] for (i = 0; i < AOIT_NODE_COUNT; ++i) {
        if (fragmentDepth > depth[i]) {
            index++;
            prevTrans = trans[i];
        }
    }

    // Make room for the new fragment. Also composite new fragment with the current curve 
    // (except for the node that represents the new fragment)
    [unroll]for (i = AOIT_NODE_COUNT - 1; i >= 0; --i) {
        [flatten]if (index <= i) {
            depth[i + 1] = depth[i];
            trans[i + 1] = trans[i] * fragmentTrans;
            color[i + 1] = color[i];
        }
    }
    
	// Insert new fragment
	const float newFragTrans = fragmentTrans * prevTrans;
	const float3 newFragColor = fragmentColor * (1 - fragmentTrans);
	[unroll]for (i = 0; i <= AOIT_NODE_COUNT; ++i) {
		[flatten]if (index == i) {
			depth[i] = fragmentDepth;
			trans[i] = newFragTrans;
			color[i] = newFragColor;
		}
	} 

#ifdef AOIT_LITBASE
	[flatten]if(ctlSurface.trans_updated == false)
	{
		ctlSurface.trans_updated = true;
		ctlSurface.last_trans = trans[AOIT_NODE_COUNT - 1];
	}
#endif

	[flatten]if (depth[AOIT_NODE_COUNT] != AOIT_EMPTY_NODE_DEPTH) {
		float3 toBeRemovedCol = color[AOIT_NODE_COUNT];
		float3 toBeAccumulCol = color[AOIT_NODE_COUNT - 1];
		color[AOIT_NODE_COUNT - 1] = toBeAccumulCol + toBeRemovedCol * trans[AOIT_NODE_COUNT - 1] *
			rcp(trans[AOIT_NODE_COUNT - 2]);
		trans[AOIT_NODE_COUNT - 1] = trans[AOIT_NODE_COUNT];
	}	
   
    // Pack AOIT data
    [unroll] for (i = 0; i < AOIT_NODE_COUNT; ++i) {
        nodeArray[i].depth = depth[i];
        nodeArray[i].trans = trans[i];
        nodeArray[i].color = color[i];
    }
}

//add color based on existed visibility 
void AOITSPInsertLightFragment(in float  fragmentDepth,
                          in float  fragmentTrans,
                          in float3 fragmentColor,
						  in float last_trans,
                          inout ATSPNode nodeArray[AOIT_NODE_COUNT])
{	
    int i;

    float  depth[AOIT_NODE_COUNT];	
    float  trans[AOIT_NODE_COUNT];	 
    float3   color[AOIT_NODE_COUNT];	 

    ///////////////////////////////////////////////////
    // Unpack AOIT data
    ///////////////////////////////////////////////////                   
    [unroll] for (i = 0; i < AOIT_NODE_COUNT; ++i) {
        depth[i] = nodeArray[i].depth;
        trans[i] = nodeArray[i].trans;
        color[i] = nodeArray[i].color;
    }	
	
    // Find insertion index 
    int index = 0;
    [unroll] for (i = 0; i < AOIT_NODE_COUNT; ++i) {
		if (fragmentDepth > depth[i]) {
            index++;
		}
    }

	// Insert new fragment
	[flatten]if(index < AOIT_NODE_COUNT && depth[index] != AOIT_EMPTY_NODE_DEPTH)
	{
		const float3 newFragColor = fragmentColor * (1 - fragmentTrans) + color[index];
		color[index] = newFragColor;
	}
	else if(index >= AOIT_NODE_COUNT)
	{
		const float3 newFragColor = fragmentColor * (1 - fragmentTrans) * last_trans * rcp(trans[AOIT_NODE_COUNT - 2]) + color[AOIT_NODE_COUNT - 1];
		color[AOIT_NODE_COUNT - 1] = newFragColor;
	}

    // Pack AOIT data
    [unroll] for (i = 0; i < AOIT_NODE_COUNT; ++i) {
        nodeArray[i].depth = depth[i];
        nodeArray[i].trans = trans[i];
        nodeArray[i].color = color[i];
    }
}

/////////////////////////////////////////////////
// Address generation functions for the AOIT data
/////////////////////////////////////////////////

uint AOITAddrGen(uint2 addr2D, uint surfaceWidth)
{
#ifdef AOIT_TILED_ADDRESSING

	surfaceWidth	  = surfaceWidth >> 1U;
	uint2 tileAddr2D  = addr2D >> 1U;
	uint  tileAddr1D  = (tileAddr2D[0] + surfaceWidth * tileAddr2D[1]) << 2U;
	uint2 pixelAddr2D = addr2D & 0x1U;
	uint  pixelAddr1D = (pixelAddr2D[1] << 1U) + pixelAddr2D[0];
	
	return tileAddr1D | pixelAddr1D;
#else
	return addr2D[0] + surfaceWidth * addr2D[1];	
#endif
}

uint AOITAddrGenUAV(uint2 addr2D)
{
	uint2 dim;
	gAOITSPClearMaskUAV.GetDimensions(dim[0], dim[1]);
	return AOITAddrGen(addr2D, dim[0]);
}

uint AOITAddrGenSRV(uint2 addr2D)
{
	uint2 dim;
	gAOITSPClearMaskSRV.GetDimensions(dim[0], dim[1]);
	return AOITAddrGen(addr2D, dim[0]);	
}

void AOITSPClearData(out ATSPNode nodeArray[AOIT_NODE_COUNT], float depth, float4 color)
{
	[unroll]for(uint i = 0; i < AOIT_NODE_COUNT; i++) {
		nodeArray[i].depth = AOIT_EMPTY_NODE_DEPTH;
		nodeArray[i].color = float3(0, 0, 0);
		nodeArray[i].trans = saturate(1.0f - color.w);
	}
	nodeArray[0].depth = depth;
	nodeArray[0].color = color.rgb * color.aaa;
}

/////////////////////////////////////////////////
// Load/store functions for the AOIT data
/////////////////////////////////////////////////
void AOITSPLoadDataSRV(in uint2 pixelAddr, out ATSPNode nodeArray[AOIT_NODE_COUNT])
{
	uint addr = AOITAddrGenSRV(pixelAddr);
	[unroll]for (uint i = 0; i < AOIT_NODE_COUNT; i++) {
		nodeArray[i].depth = 0;
		nodeArray[i].color = _AOITSPColorDataSRV[addr].color[i];
		nodeArray[i].trans = _AOITSPColorDataSRV[addr].trans[i];
	}
}


void AOITSPLoadDataUAV(in uint2 pixelAddr, out ATSPNode nodeArray[AOIT_NODE_COUNT])
{
	uint addr = AOITAddrGenUAV(pixelAddr);
	[unroll]for (uint i = 0; i < AOIT_NODE_COUNT; i++) {
		nodeArray[i].depth = _AOITSPDepthDataUAV[addr].depth[i];
		nodeArray[i].color = _AOITSPColorDataUAV[addr].color[i];
		nodeArray[i].trans = _AOITSPColorDataUAV[addr].trans[i];
	}
}

void AOITSPStoreDataUAV(in uint2 pixelAddr, ATSPNode nodeArray[AOIT_NODE_COUNT])
{
	uint addr = AOITAddrGenUAV(pixelAddr);
	[unroll]for (uint i = 0; i < AOIT_NODE_COUNT; i++) {
		_AOITSPDepthDataUAV[addr].depth[i] = nodeArray[i].depth;
		_AOITSPColorDataUAV[addr].color[i] = nodeArray[i].color;
		_AOITSPColorDataUAV[addr].trans[i] = nodeArray[i].trans;
	}
}



/////////////////////////////////////////////////////////////
// Control Surface functions for the AOIT data
// We use this surface to remove the overhead incurred in 
// clearing large AOIT buffers by storing for each
// pixel on the screen a to-be-cleared flag.
// We use the same structure to store some additional
// per-pixel information such as the depth of the most
// distant transparent fragment and its total transmittance,
// which in turn can be used to perform early-z culling over
// pixels covered by transparent fragments
/////////////////////////////////////////////////////////////

void AOITLoadControlSurface(in uint data, inout AOITCtrlSurface surface)
{
	surface.clear	= data & 0x1 ? true : false;
	surface.trans_updated = data & 0x2 ? true : false;
	surface.last_trans = asfloat(data & 0xFFFFFFFCUL);
}

void AOITLoadControlSurfaceUAV(in uint2 pixelAddr, inout AOITCtrlSurface surface)
{
	uint data = gAOITSPClearMaskUAV[pixelAddr];
	AOITLoadControlSurface(data, surface);
}

void AOITLoadControlSurfaceSRV(in uint2 pixelAddr, inout AOITCtrlSurface surface)
{
	uint data = gAOITSPClearMaskSRV[pixelAddr];
	AOITLoadControlSurface(data, surface);
}

void AOITStoreControlSurface(in uint2 pixelAddr, in AOITCtrlSurface surface)
{
	uint data = surface.clear  ? 0x1 : 0x0;	 
	data |= surface.trans_updated ? 0x2 : 0x0;
	data |= (asuint(surface.last_trans) & 0xFFFFFFFCUL);
	gAOITSPClearMaskUAV[pixelAddr] = data;
}

void WriteNewPixelToAOIT(float2 Position, float  surfaceDepth, float4 surfaceColor)
{	
	//if(surfaceColor.a <= 0.01)
	//	return;
	if(surfaceColor.a <= 0)
		return;
	if(surfaceColor.a * surfaceColor.r <= 0 && surfaceColor.a * surfaceColor.g <= 0 && surfaceColor.a * surfaceColor.b <= 0)
		return;
	// From now on serialize all UAV accesses (with respect to other fragments shaded in flight which map to the same pixel)
	ATSPNode nodeArray[AOIT_NODE_COUNT];    
	uint2 pixelAddr = uint2(Position.xy);


	// Load AOIT control surface
	AOITCtrlSurface ctrlSurface;
	AOITLoadControlSurfaceUAV(pixelAddr, ctrlSurface);

	// If we are modifying this pixel for the first time we need to clear the AOIT data
	if (ctrlSurface.clear) 
	{			
		// Clear AOIT data and initialize it with first transparent layer
		AOITSPClearData(nodeArray, surfaceDepth, surfaceColor);			

		// Store AOIT data
		AOITSPStoreDataUAV(pixelAddr, nodeArray);
			
		// Update control surface
        // ( depth and opaque flag can be used to branch out early if adding behind already near-opaque contents of AOIT )
		// ctrlSurface.clear  = false;			
		// ctrlSurface.opaque = false; // 1.f == surfaceColor.w;
		// ctrlSurface.depth  = 0; // surfaceDepth;
		// AOITStoreControlSurface(pixelAddr, ctrlSurface);

        //gAOITSPClearMaskUAV[pixelAddr] = 0;
		ctrlSurface.clear = false;
		ctrlSurface.trans_updated = false;
		ctrlSurface.last_trans = 0.0;
	} 
	else 
	{ 
		// Load AOIT data
		AOITSPLoadDataUAV(pixelAddr, nodeArray);

		// Update AOIT data
		AOITSPInsertFragment(surfaceDepth,		
							 1.0f - surfaceColor.w,  // transmittance = 1 - alpha
							 surfaceColor.xyz,
							 nodeArray,
							 ctrlSurface);
		// Store AOIT data
		AOITSPStoreDataUAV(pixelAddr, nodeArray);
	}
	AOITStoreControlSurface(pixelAddr, ctrlSurface);
}

void WriteLightPixelToAOIT(float2 Position, float  surfaceDepth, float4 surfaceColor)
{	
	//if(surfaceColor.a <= 0.01)
	//	return;
	if(surfaceColor.a <= 0)
		return;
	if(surfaceColor.a * surfaceColor.r <= 0 && surfaceColor.a * surfaceColor.g <= 0 && surfaceColor.a * surfaceColor.b <= 0)
		return;
	// From now on serialize all UAV accesses (with respect to other fragments shaded in flight which map to the same pixel)
	ATSPNode nodeArray[AOIT_NODE_COUNT];    
	uint2 pixelAddr = uint2(Position.xy);

	// Load AOIT control surface
	AOITCtrlSurface ctrlSurface;
	AOITLoadControlSurfaceUAV(pixelAddr, ctrlSurface);

	// If we are modifying this pixel for the first time we need to clear the AOIT data
	if (!ctrlSurface.clear) 
	{ 
		// Load AOIT data
		AOITSPLoadDataUAV(pixelAddr, nodeArray);

		// Update AOIT data
		AOITSPInsertLightFragment(surfaceDepth,		
							 1.0f - surfaceColor.w,  // transmittance = 1 - alpha
							 surfaceColor.xyz,
							 ctrlSurface.last_trans,
							 nodeArray);
		// Store AOIT data
		AOITSPStoreDataUAV(pixelAddr, nodeArray);

		ctrlSurface.trans_updated = false;
		AOITStoreControlSurface(pixelAddr, ctrlSurface);
	}	
}
#endif // H_AOIT

