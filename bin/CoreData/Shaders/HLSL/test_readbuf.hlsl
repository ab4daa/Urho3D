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
	Texture2D<uint> readbuf : register(t0);
    StructuredBuffer<testRWStruc> readbuf2 : register(t1);
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
    float4 iPos : SV_POSITION,
    out float4 oColor : OUTCOLOR0)
{
    uint2 pixelAddr = uint2(iPos.xy);
    uint2 dim;
	readbuf.GetDimensions(dim[0], dim[1]);
    
    oColor = float4(float(readbuf[pixelAddr]) * cGBufferInvSize.x,
        float(readbuf2[pixelAddr.y * dim.x + pixelAddr.x].data) * cGBufferInvSize.x,
        0.0,
        1.0 );  
}
