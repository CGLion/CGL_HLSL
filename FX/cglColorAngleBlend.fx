/* 
 * CG-Lion Color-Angle-Blend HLSL shader written by Oded Erell (c)2020
 *
 * Description:
 * Outputs a blend between 2 color sources according to surface view angle.
 * Parameters:
 * facingColor: The color (or texture) that will appear at perpendicular view angle.
 * sideColor: The color (or texture) that will appear at grazing view angle.
 * baseBlend: The percent of side_color that is mixed with facing_color at perpendicular view angle.
 * curveExponent: A power exponent value by which the blend value is raised to control the blend curve.
 * for example, a value of 1.0 will output a linear blend, while a value of 3.0
 * will output a 'slow' curve that shows facing_color at more angles and side_color only at extreme grazing angle.
 */

// ---- Tweakables ---- :

float4 facingColor : Color
<
	string UIName = "Facing Color";
> = {0.0f, 0.0f, 0.0f, 1.0f};

float4 sideColor : Color
<
	string UIName = "Side Color";
> = {1.0f, 1.0f, 1.0f, 1.0f};

float baseBlend
<
	string UIWidget = "slider";
	float UIMin = 0.0f;
	float UIMax = 1.0f;
	string UIName = "Base Blend";
> = 0.0f;

float curveExponent
<
	string UIWidget = "slider";
	float UIMin = 0.001f;
	float UIMax = 10.0f;
	string UIName = "Curve Exponent";
> = 1.0f;

// ---- CPU to GPU imput matrices ---- :
// (automatically tracked tweakables)

float4x4 ViewInverse 			: ViewInverse 			< string UIWidget = "None"; >;
float4x4 WorldInverseTranspose 	: WorldInverseTranspose < string UIWidget = "None"; >;
float4x4 WorldViewProjection 	: WorldViewProjection 	< string UIWidget = "None"; >;
// Object > World:
float4x4 World 					: World					 < string UIWidget = "None" ;>;



// ---- Shader Functions ---- :

// struct - input from app to vertex shader:
struct a2v
{
	float4 position : POSITION;
	float3 normal 	: NORMAL;
};

// struct - output from vertex shader to pixel shader:
struct v2p
{
	float4 ssPosition 	: POSITION;
	float4 wsPosition 	: TEXCOORD1;
	float3 wsNormal 	: TEXCOORD2;
	float3 camVector 	: TEXCOORD3;
};

// Vertex Shader Function:
v2p vShader (a2v In)
{
	v2p Out;
	Out.wsNormal = normalize(mul(In.normal, WorldInverseTranspose).xyz);
	float4 screenPos = mul(In.position, WorldViewProjection); // Object Space > Screen Space
	Out.ssPosition = screenPos;
	float4 wsPos = mul(In.position, World); // Object Space > Worl Space
	Out.wsPosition = wsPos;
	Out.camVector = normalize(ViewInverse[3].xyz - wsPos);
	return Out;
}

// Pixel Shader Fuction (fragment program):
float4 pShader (v2p In) : COLOR
{
	float blendFactor = pow(acos(dot(In.wsNormal,In.camVector))/1.57079632679489f,curveExponent);
	float4 mixedFacingColor = ((1-baseBlend)*facingColor) + (baseBlend * sideColor);
	return ((1-blendFactor) * mixedFacingColor) + (blendFactor * sideColor);
}



// ---- Techniques ---- :

technique basic
{
	pass one
	{
		VertexShader = compile vs_1_1 vShader();
		ZEnable = true;
		ZWriteEnable = true;
		CullMode = CW;
		AlphaBlendEnable = false;
		PixelShader = compile ps_2_0 pShader();
	}
}