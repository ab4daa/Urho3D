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
    float4 iPos : SV_POSITION)
{    
    uint2 pixelAddr = uint2(iPos.xy);

	uint addr = AOITAddrGenUAV(pixelAddr);

	uint data = 0x1; // is clear
	gAOITSPClearMaskUAV[pixelAddr] = data;
}
