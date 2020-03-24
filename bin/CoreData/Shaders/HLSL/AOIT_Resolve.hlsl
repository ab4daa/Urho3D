#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "AOIT.hlsl"


void VS(float4 iPos : POSITION,
    out float2 oTexCoord : TEXCOORD0,
    out float2 oScreenPos : TEXCOORD1,
    out float4 oPos : OUTPOSITION)
{
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    oPos = GetClipPos(worldPos);
    oTexCoord = GetQuadTexCoord(oPos);
    oScreenPos = GetScreenPosPreDiv(oPos);
}

void PS(
    float2 iTexCoord : TEXCOORD0,
    float2 iScreenPos : TEXCOORD1,
	float4 iPos : SV_POSITION,
    out float4 oColor : OUTCOLOR0)
{    
    uint2 pixelAddr = uint2(iPos.xy);
    oColor = float4(0, 0, 0, 1);
    // display debug colour
    //return float4( 0, 1, 0, 1.0 );

	// Load control surface
	AOITCtrlSurface ctrlSurface;
	AOITLoadControlSurfaceSRV(pixelAddr, ctrlSurface);

	// Any transparent fragment contributing to this pixel?
	if (!ctrlSurface.clear) 
	{
		// Load all nodes for this pixel    
		ATSPNode nodeArray[AOIT_NODE_COUNT];
		AOITSPLoadDataSRV(pixelAddr, nodeArray);

		// Accumulate final transparent colors
		float  trans = 1;
		float3 color = 0;       
		[unroll]for(uint i = 0; i < AOIT_NODE_COUNT; i++) {
#ifdef dohdr
			color += trans * FromRGBE(UnpackRGBA(nodeArray[i].color));
#else
			color += trans * UnpackRGB(nodeArray[i].color);
#endif
			trans  = nodeArray[i].trans / 255;
		}
		oColor = float4(color, nodeArray[AOIT_NODE_COUNT - 1].trans / 255);
	}

    // blend accumualted transparent color with opaque background color
    //return outColor;
}
