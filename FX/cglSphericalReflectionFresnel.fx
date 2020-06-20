/* 
 * CG-Lion Spherical Reflection Fresnel HLSL shader written by Oded Erell (c)2020
 *
 * Description:
 * Outputs a blend of flat color and Fresnel reflection from spherical environment map.
 * Parameters:
 * diffuseColor: The material's Diffuse color
 * ior: The material's refractive index
 * envMap: A spherical formatted evvironment map (latitude longitute)
 * envScale: Environment scale (exposure)
 * envGamma: A gamma value used to linearize the environment texture
 */

// ---- Tweakables ---- :

float4 diffuseColor : Color
<
	string UIName = "Diffuse Color";
> = {0.0f, 0.0f, 0.0f, 1.0f};

float ior
<
	string UIWidget = "slider";
	float UIMin = 1.0f;
	float UIMax = 5.0f;
	string UIName = "IOR";
> = 1.5f;

texture envMap : EnvironmeMapMap
<
	string UIName = "Environment Texture";
    string TextureType = "2D";
>;

float envScale
<
	string UIWidget = "slider";
	float UIMin = 0.01f;
	float UIMax = 100.0f;
	string UIName = "Environment Color Scale";
> = 1.0f;

float envGamma
<
	string UIWidget = "slider";
	float UIMin = 0.001f;
	float UIMax = 5.0f;
	string UIName = "Environment Gamma";
> = 2.2f;

sampler2D envMapSampler = sampler_state
{
	Texture = <envMap>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Anisotropic;
};

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
	float2 UV		: TEXCOORD0;
	float3 normal 	: NORMAL;
};

// struct - output from vertex shader to pixel shader:
struct v2p
{
	float4 ssPosition 	: POSITION;
	float2 UV			: TEXCOORD0;
	float4 wsPosition 	: TEXCOORD1;
	float3 wsNormal 	: TEXCOORD2;
	float3 wsIncoming 	: TEXCOORD3;
};

// Vertex Shader Function:

float2 sphericalSample(float3 viewVec)
{
	float Pi = 3.1415926535897932384f;
	float2 longVec = viewVec.xy;
	float2 latVec = float2(length(longVec),viewVec.z);
	float u = acos( dot( normalize( longVec ), float2(1.0f, 0.0f))) / Pi;
	float latAngle = acos( dot( normalize( latVec  ), float2(1.0f, 0.0f)));
	float v = 0.5f - ((viewVec.z >= 0.0f ? latAngle : -latAngle) / Pi);
	return float2(u,v);
}

float fresnelReflection(float ior, float3 invec, float3 nrmvec)
{
	float a, b;
	float c = abs( dot(invec, nrmvec) );
	float g = ior * ior - 1.0f + c * c;
	float fr = 1.0f;
	if (g > 0) {
		g = sqrt(g);
		a = (g - c) / (g + c);
		b = (c * (g + c) - 1.0f) / (c * (g - c) + 1.0f);
		fr = 0.5f * a * a * (1.0f + b * b);
	}
	return fr;
}

v2p vShader (a2v In)
{
	v2p Out;
	Out.wsNormal = normalize(mul(In.normal, WorldInverseTranspose).xyz);
	float4 screenPos = mul(In.position, WorldViewProjection); // Object Space > Screen Space
	Out.ssPosition = screenPos;
	Out.UV = In.UV;
	float4 wsPos = mul(In.position, World); // Object Space > Worl Space
	Out.wsPosition = wsPos;
	Out.wsIncoming = normalize(wsPos - ViewInverse[3].xyz);
	return Out;
}

// Pixel Shader Fuction (fragment program):
float4 pShader (v2p In) : COLOR
{
	float3 refVec = In.wsIncoming - (2 * (dot(In.wsIncoming,In.wsNormal))) * In.wsNormal;
	float4 specColor = tex2D(envMapSampler, sphericalSample(refVec));
	specColor = pow(specColor,envGamma) * envScale;
	float specFr = fresnelReflection(ior,In.wsIncoming,In.wsNormal);
	float4 finalColor = ((1 - specFr) * diffuseColor) + ( specFr * specColor );
	return finalColor;
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
		PixelShader = compile ps_3_0 pShader();
	}
}