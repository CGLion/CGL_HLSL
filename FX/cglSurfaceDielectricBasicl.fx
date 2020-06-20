/* 
 * CG-Lion Surface Dielectric Basic HLSL shader written by Oded Erell (c)2020
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

int diffuseSamples
<
	string UIWidget = "slider";
	float UIMin = 3;
	float UIMax = 15;
	string UIName = "Diffuse Samples";
> = 5;

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

texture envDiffMap : EnvironmeMapMap
<
	string UIName = "Environment Diffuse Texture";
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

sampler2D envDiffMapSampler = sampler_state
{
	Texture = <envDiffMap>;
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
float Pi = 3.1415926535897932384f;


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

float2 vecToAngles(float3 vec)
{
	float2 longVec = vec.xy;
	float2 latVec = float2(length(longVec),vec.z);
	float longAngle = acos( dot( normalize( longVec ), float2(1.0f, 0.0f)));
	float rawLatAngle = acos( dot( normalize( latVec  ), float2(1.0f, 0.0f)));
	float latAngle = (Pi * 0.5f) - (vec.z >= 0.0f ? rawLatAngle : -rawLatAngle);
	return float2(longAngle,latAngle);
}

float3 anglesToVec(float longAngle, float latAngle)
{
	float2 longVec = float2(cos(longAngle), sin(longAngle));
	longVec *= cos(latAngle);
	return float3 (longVec,sin((Pi * 0.5f) - latAngle));
}

float2 sphericalSample(float3 viewVec)
{
	float2 angles = vecToAngles(viewVec);
	float u = angles.x / Pi;
	float v = angles.y / Pi;
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

float4 diffuseEnvSample( float3 viewVec )
{
/* 	float angIncr = spread / (samples - 1);
	float2 viewAngles = vecToAngles(viewVec);
	float4 irr = 0.0;
	for (int i = 0; i < samples; i++)
	{
		for(int j = 0; j < samples; j++)
		{
			float2 offVec = anglesToVec(viewAngles.x - (spread * 0.5) + (i * angIncr),viewAngles.y - (spread * 0.5) + (i * angIncr));
			irr += pow(tex2D(envMapSampler, offVec),envGamma);
		}
	}
	irr /= pow(samples,2);
	return irr; */
	return pow(tex2D(envDiffMapSampler, sphericalSample(viewVec)),envGamma);
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
	float4 Irrad = diffuseEnvSample(In.wsNormal);
	float4 finalDiff = Irrad * envScale * diffuseColor;
	float4 finalColor = ((1 - specFr) * finalDiff) + ( specFr * specColor );
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