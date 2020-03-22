#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"

#ifdef COMPILEPS
	#ifndef D3D11
	#else
    struct testRWStruc
    {
        uint data;
    };
	RasterizerOrderedTexture2D<uint> writebuf : register(u0);
    RWStructuredBuffer<testRWStruc> writebuf2 : register(u1);
	#endif
#endif

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
    writebuf[pixelAddr] = uint(iPos.x*abs(sin(cElapsedTimePS)));    
    uint2 dim;
	writebuf.GetDimensions(dim[0], dim[1]);
    writebuf2[pixelAddr.y * dim.x + pixelAddr.x].data = uint(iPos.x*abs(sin(cElapsedTimePS)));
}
