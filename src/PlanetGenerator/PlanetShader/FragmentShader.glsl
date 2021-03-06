varying vec3 vPosition;
varying vec3 viewVector;
varying mat4 modelMatrixFrag;

uniform vec3 iResolution;
uniform float iTime;

//Planet parameters
uniform vec3 _PSNoiseOffset;
uniform float _PSNoiseGlobalScale;
uniform float _PSWaterHeight;
uniform float _PSWaterDepthOffset;
uniform float _PSMaxHeightOffset;
uniform vec3 _PlanetColor1;
uniform vec3 _PlanetColor2;
uniform vec2 _PSNoiseScales;
uniform float _SecondaryNoiseStrengthGround;
uniform float _MaxScrewTerrain;
uniform float _PSDensityOffset;
uniform float _SurfaceMinLight;

uniform float _GridHalfSize;
uniform float _VoxelNormalInterp;
uniform bool _EnableVoxelizer;

uniform float _PlanetSurfaceWaterStepSize;
uniform float _PlanetSurfaceWaterMaxStepCount;


//Ocean uniforms
uniform vec3 _WaterColorDepth;
uniform vec3 _WaterColor;
uniform vec2 _WaterMaterialSmoothStep;
uniform float _WaterNormalScale;
uniform float _WaterSurfaceMinLight;
uniform float _WaterNormalStrength;
uniform vec2 _SpecularParams;
uniform float _WaterMoveSpeed;
//Cloud parameters
uniform float _CloudTransparency;
uniform vec3 _CloudColor1;
uniform vec3 _CloudColor2;
uniform float _MaxScrewCloud;
uniform float _BreakDistanceCloud;
uniform float _CloudMidDistance;
uniform float _CloudHalfHeight;
uniform vec2 _CloudNoiseScales;
uniform vec3 _CloudNoiseOffset;
uniform float _CloudNoiseGlobalScale;
uniform float _SecondaryNoiseStrength;
uniform float _CloudDensityMultiplier;
uniform float _CloudDensityOffset;
uniform float _CloudMoveSpeed;

uniform float _CloudsStepSize;
uniform float _CloudsMaxStepCount;

uniform bool _CloudsPosterize;
uniform float _CloudsPosterizeCount;

//Ambient Parameters
uniform vec3 _AmbientColor;
uniform float _AmbientPower;

const vec3 lDirection = normalize(vec3(1,0,1));

//Misc
uniform float _CylinderHeight;
uniform float _CylinderRad;

void Unity_RotateAboutAxis_Radians_float(vec3 In, vec3 Axis, float Rotation, out vec3 Out)
{
    float s = sin(Rotation);
    float c = cos(Rotation);
    float one_minus_c = 1.0 - c;

    Axis = normalize(Axis);
    vec3 r0 = vec3(one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s);
    vec3 r1 = vec3(one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s);
    vec3 r2 = vec3(one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c);

    mat3 rot_mat;
    rot_mat[0] = r0;
    rot_mat[1] = r1;
    rot_mat[2] = r2;

    Out = (rot_mat * In).xyz;
}

vec3 hash( vec3 p ) // replace this by something better. really. do
{
	p = vec3( dot(p,vec3(127.1,311.7, 74.7)),
			  dot(p,vec3(269.5,183.3,246.1)),
			  dot(p,vec3(113.5,271.9,124.6)));

	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

// returns 3D value noise (in .x)  and its derivatives (in .yzw)
vec4 noised( in vec3 x )
{
    // grid
    vec3 p = floor(x);
    vec3 w = fract(x);
    
    // quintic interpolant
    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);
    
    // gradients
    vec3 ga = hash( p+vec3(0.0,0.0,0.0) );
    vec3 gb = hash( p+vec3(1.0,0.0,0.0) );
    vec3 gc = hash( p+vec3(0.0,1.0,0.0) );
    vec3 gd = hash( p+vec3(1.0,1.0,0.0) );
    vec3 ge = hash( p+vec3(0.0,0.0,1.0) );
    vec3 gf = hash( p+vec3(1.0,0.0,1.0) );
    vec3 gg = hash( p+vec3(0.0,1.0,1.0) );
    vec3 gh = hash( p+vec3(1.0,1.0,1.0) );
    
    // projections
    float va = dot( ga, w-vec3(0.0,0.0,0.0) );
    float vb = dot( gb, w-vec3(1.0,0.0,0.0) );
    float vc = dot( gc, w-vec3(0.0,1.0,0.0) );
    float vd = dot( gd, w-vec3(1.0,1.0,0.0) );
    float ve = dot( ge, w-vec3(0.0,0.0,1.0) );
    float vf = dot( gf, w-vec3(1.0,0.0,1.0) );
    float vg = dot( gg, w-vec3(0.0,1.0,1.0) );
    float vh = dot( gh, w-vec3(1.0,1.0,1.0) );
	
    // interpolation
    float v = va + 
              u.x*(vb-va) + 
              u.y*(vc-va) + 
              u.z*(ve-va) + 
              u.x*u.y*(va-vb-vc+vd) + 
              u.y*u.z*(va-vc-ve+vg) + 
              u.z*u.x*(va-vb-ve+vf) + 
              u.x*u.y*u.z*(-va+vb+vc-vd+ve-vf-vg+vh);
              
    vec3 d = ga + 
             u.x*(gb-ga) + 
             u.y*(gc-ga) + 
             u.z*(ge-ga) + 
             u.x*u.y*(ga-gb-gc+gd) + 
             u.y*u.z*(ga-gc-ge+gg) + 
             u.z*u.x*(ga-gb-ge+gf) + 
             u.x*u.y*u.z*(-ga+gb+gc-gd+ge-gf-gg+gh) +   
             
             du * (vec3(vb-va,vc-va,ve-va) + 
                   u.yzx*vec3(va-vb-vc+vd,va-vc-ve+vg,va-vb-ve+vf) + 
                   u.zxy*vec3(va-vb-ve+vf,va-vb-vc+vd,va-vc-ve+vg) + 
                   u.yzx*u.zxy*(-va+vb+vc-vd+ve-vf-vg+vh) );
                   
    return vec4( v, d.xyz );                   
}

vec2 sphIntersect( in vec3 ro, in vec3 rd, in vec3 ce, float ra ) //from https://iquilezles.org/www/articles/intersectors/intersectors.htm
{
    vec3 oc = ro - ce;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - ra*ra;
    float h = b*b - c;
    if( h<0.0 ) return vec2(-1.0, 0); // no intersection
    h = sqrt( h );
    return vec2( -b-h, -b+h );
}

float InvLerp(float a, float b, float v){
    return (v - a) / (b - a);
}

vec3 SpherePlanarMapping(vec3 positionOS, float cyRad, float cyHeight, float sRad){
    float halfHeight = cyHeight/2.0;
    float maxAngle = atan(halfHeight/ cyRad);

    float planeMag = length(vec2(positionOS.x, positionOS.z));
    float currentVerticalAngle = atan(positionOS.y/ planeMag);
    float currentHeight = cyRad * (positionOS.y / planeMag);
    float verticalMask = smoothstep(maxAngle, maxAngle - 0.3, abs(currentVerticalAngle));
    
    
    vec2 nUV = vec2(0.0,0.0);
    

    vec3 planeVector = normalize(vec3(positionOS.x, 0.0, positionOS.z));
    float dotAxis = dot(vec3(1.0,0.0,0.0), planeVector);
    float horizAngle = acos(dotAxis)/3.1415;
    float dotAxisSign = sign(cross(vec3(1.0, 0.0, 0.0), planeVector).y);
    float dotAxisRemap = horizAngle;
    nUV.x = ((dotAxisSign * dotAxisRemap) + 1.0)/2.0;//horizAngle;//((dotAxisSign * dotAxisRemap) + 1)/2; //dotAxisRemap;//((dotAxisSign * dotAxisRemap) + 1)/2;
    nUV.y = InvLerp(-halfHeight, halfHeight, currentHeight);//* verticalMask;

    return vec3(nUV, verticalMask);
}

float unity_noise_randomValue (vec2 uv)
{
    return fract(sin(dot(uv, vec2(12.9898, 78.233)))*43758.5453);
}

float cloudNoise2(vec3 p){
    float screwInterp = p.y + 0.5;
    vec3 screwedPos = vec3(0,0,0);
    Unity_RotateAboutAxis_Radians_float(p, vec3(0,1,0), screwInterp * _MaxScrewCloud, screwedPos);
    vec3 samplePos = (screwedPos + _CloudNoiseOffset) * _CloudNoiseGlobalScale;

    vec3 np = vec3(0,0,0);
    Unity_RotateAboutAxis_Radians_float(samplePos, vec3(0,1,0), iTime * _CloudMoveSpeed, np);
    float density = noised(np * _CloudNoiseScales.x).x + noised(samplePos * _CloudNoiseScales.y).x * _SecondaryNoiseStrength;
    return density * _CloudDensityMultiplier + _CloudDensityOffset;
}

float cloudDistanceMask(float dist){
    float cloudMidDist = _CloudMidDistance * 2.0;
    float minHeight = _CloudHalfHeight * 2.0;
    return smoothstep(cloudMidDist - minHeight,cloudMidDist, dist) * smoothstep(cloudMidDist + minHeight, cloudMidDist, dist);
}

float SampleCloudDensity(vec3 p){
    float density = cloudNoise2(p);
    float dist = length(p) * 2.0;
    float heightMask = cloudDistanceMask(dist);
    return density * heightMask;
}

vec3 calcCloudNormal( in vec3 sp ) // for function f(p) // From https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
{
    const float h = 0.0001; // replace by an appropriate value
    const vec2 k = vec2(1,-1);
    return normalize( k.xyy*SampleCloudDensity( sp + k.xyy*h ) + 
                      k.yyx*SampleCloudDensity( sp + k.yyx*h ) + 
                      k.yxy*SampleCloudDensity( sp + k.yxy*h ) + 
                      k.xxx*SampleCloudDensity( sp + k.xxx*h ) );
}

void cloudRender(vec3 viewVector, vec3 positionOS, out float value, out vec3 hitPos){
    float stepSize = _CloudsStepSize;
    float totalDensity = 0.0;

    vec3 uvMask = SpherePlanarMapping(positionOS, _CylinderRad, _CylinderHeight, 1.0);
    float noiseValue = unity_noise_randomValue(uvMask.xy) + unity_noise_randomValue(uvMask.yx + iTime);
    noiseValue = noiseValue/2.0;

    vec3 currentPosition = positionOS + viewVector * mix(0.0, stepSize, noiseValue);
    float cloudLightIntensity = -1.0;

    for(int i = 0; i < int(floor(_CloudsMaxStepCount)); i ++){
        float cDist = length(currentPosition);

        if(cDist > _BreakDistanceCloud) break; //Exit if outside the sphere
        
        if(cDist < _CloudMidDistance - _CloudHalfHeight){

            vec2 sInter = sphIntersect(currentPosition, viewVector, vec3(0.0,0.0,0.0), _CloudMidDistance - _CloudHalfHeight);
            currentPosition = currentPosition + viewVector * max(sInter.x, sInter.y) * (1.0 + mix(stepSize * 0.3, stepSize * 1.3, noiseValue));
        }
        if(cDist < _PSWaterHeight) break; //Hit surface

        float cloudSample = clamp(SampleCloudDensity(currentPosition), 0.0, 1.0);
        if(cloudSample > 0.1){
            
            vec3 lColor = vec3(0,0,0);

            vec3 cloudNormal = -calcCloudNormal(currentPosition);
            cloudLightIntensity = clamp(dot(cloudNormal, lDirection), 0.0, 1.0);

            //cloudLightIntensity = float(i) / 200.0;
            break;
        }

        currentPosition += viewVector * stepSize;
    }
    hitPos = currentPosition;
    value = cloudLightIntensity;
}

void SampleCloudShadowPlanet(vec3 position, vec3 lightDir,out float lightOcclusion){
    //Considering 
    vec2 intersectionT = sphIntersect(position, lightDir, vec3(0,0,0), _CloudMidDistance);
    float t = intersectionT.x < intersectionT.y ? intersectionT.y : intersectionT.x;
    //float t = intersectionT.y;
    vec3 sampleShadowPos = position + lightDir * t;

    float density = SampleCloudDensity(sampleShadowPos);
    lightOcclusion = 1.0 - smoothstep(0.0, 0.05, density);
}

float distSphere(vec3 samplePos, vec3 spherePos, float sphereRad){
    return length(samplePos - spherePos) - sphereRad;
}

float planetNoise(vec3 pos){
    float cDist = length(pos);
    
    vec3 normPos = normalize(pos);
    float screwInterp = ((pos.y / (_PSMaxHeightOffset + _PSWaterHeight)) + 1.0)/2.0;
    
    //_MaxScrewCloud
    
    vec3 screwedPos = vec3(0.0,0.0,0.0);
    Unity_RotateAboutAxis_Radians_float(normPos, vec3(0.0,1.0,0.0), screwInterp * _MaxScrewTerrain, screwedPos);
    vec3 samplePos = (screwedPos + _PSNoiseOffset) * _PSNoiseGlobalScale;

    float heightMask = 1.0 - InvLerp(_PSWaterHeight, _PSWaterHeight + _PSMaxHeightOffset, cDist);
    //float sample = noised(samplePos * 4).x * heightMask;
    float noiseSample = (noised(samplePos * _PSNoiseScales.x).x + noised(samplePos * _PSNoiseScales.y).x * _SecondaryNoiseStrengthGround + _PSDensityOffset) * heightMask;

    return mix(noiseSample, 1.0, 1.0 - smoothstep(_PSWaterHeight - _PSWaterDepthOffset, _PSWaterHeight, cDist));
}

vec3 calcPlanetNormal( in vec3 sp ) // for function f(p) // From https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
{
    const float h = 0.0001; // replace by an appropriate value
    const vec2 k = vec2(1.0,-1.0);
    return normalize( k.xyy*planetNoise( sp + k.xyy*h ) + 
                      k.yyx*planetNoise( sp + k.yyx*h ) + 
                      k.yxy*planetNoise( sp + k.yxy*h ) + 
                      k.xxx*planetNoise( sp + k.xxx*h ) );
}

float specular(vec3 lightDirection, vec3 normal, vec3 viewVector){
    vec3 VertexToEye = -viewVector;
    vec3 LightReflect = normalize(reflect(lightDirection, normal));
    float SpecularFactor = dot(VertexToEye, LightReflect);
    SpecularFactor = pow(SpecularFactor, _SpecularParams.x);
    SpecularFactor = _SpecularParams.y * SpecularFactor;
    return SpecularFactor;
}

float planetLightOcclusion(vec3 planetSurfacePos){
    float lightOcclusion = 1.0;
    if(length(planetSurfacePos) < _CloudMidDistance){
        SampleCloudShadowPlanet(planetSurfacePos, lDirection, lightOcclusion);
        lightOcclusion = mix(1.0, lightOcclusion,_CloudTransparency);
    }
    return lightOcclusion;
}

vec3 getWaterNormal(vec3 rayoriginOS, vec3 viewVector, vec3 surfacePos, out vec3 waterHitPosNearOut, out float waterMaterialOut){
    float waterMaterial = 0.0;
    vec2 waterIntersections = sphIntersect(rayoriginOS, viewVector, vec3(0,0,0), _PSWaterHeight);
    vec3 waterHitPosNear = rayoriginOS + viewVector * min(waterIntersections.x, waterIntersections.y);
    waterHitPosNearOut = waterHitPosNear;
    vec3 waterHitPosFar = rayoriginOS + viewVector * max(waterIntersections.x, waterIntersections.y); 

    if(surfacePos.x >= 0.0){
        waterMaterial = length(surfacePos*100.0 - waterHitPosNear*100.0);
    }else{
        waterMaterial = length(waterHitPosNear*100.0 - waterHitPosFar*100.0);
    }
    waterMaterialOut = waterMaterial;

    vec3 n1 = noised(normalize(waterHitPosNear) * _WaterNormalScale).yzw;
    vec3 rotatedHitPos = vec3(0.0);
    Unity_RotateAboutAxis_Radians_float(waterHitPosNear, vec3(0.0,1.0,0.0), iTime * _WaterMoveSpeed, rotatedHitPos);
    vec3 n2 = noised(normalize(rotatedHitPos) * _WaterNormalScale).yzw;
    
    vec3 waterNormal = normalize( ((n1 + n2) *_WaterNormalStrength / 2.0) + normalize(waterHitPosNear));

    return waterNormal;
}

void planetShading(bool hitSurface, vec3 rayoriginOS, vec3 viewVector, vec3 surfacePos, vec3 highInterpPosition, vec3 newNormal, bool useNewNormal, out vec3 color, out vec3 hitPos){
    
    bool hitWater = false;
    if(hitSurface){
        hitWater = length(surfacePos) < _PSWaterHeight;
    }else{
        vec2 waterIntersect = sphIntersect(rayoriginOS, viewVector, vec3(0.0), _PSWaterHeight);
        hitWater = waterIntersect.x >= 0.0;
    }

    if(!hitWater && !hitSurface){
        color = vec3(-1,0,0);
        hitPos = vec3(0.0);
    }else if(!hitWater && hitSurface){
        vec3 planetNormal = useNewNormal? mix(-calcPlanetNormal(surfacePos), newNormal, _VoxelNormalInterp) : -calcPlanetNormal(surfacePos);
        
        float lightIntensity = mix(_SurfaceMinLight, 1.0, clamp(dot(planetNormal, lDirection), 0.0, 1.0) * planetLightOcclusion(surfacePos));
        float hightColorInterp = smoothstep(_PSWaterHeight, _PSWaterHeight + _PSMaxHeightOffset, length(highInterpPosition));
        
        color = mix(_PlanetColor1.xyz, _PlanetColor2.xyz, vec3(hightColorInterp)) * lightIntensity;
        hitPos = surfacePos;
    }else if(hitWater){
        vec3 waterHitPosNear = vec3(0.0);
        float waterMaterial = 0.0;
        vec3 waterNormal = getWaterNormal(rayoriginOS, viewVector, hitSurface ? surfacePos : vec3(-1.0), waterHitPosNear, waterMaterial);
        float lightOcclusion = planetLightOcclusion(waterHitPosNear);

        waterMaterial = smoothstep(_WaterMaterialSmoothStep.x, _WaterMaterialSmoothStep.y, waterMaterial);
        hitPos = waterHitPosNear;

        float lightIntensity = clamp(dot(waterNormal, lDirection), 0.0, 1.0) * lightOcclusion;
        lightIntensity = mix(_WaterSurfaceMinLight,1.0, lightIntensity);

        color = mix(_WaterColorDepth.xyz, _WaterColor.xyz, vec3(waterMaterial)) * lightIntensity;
        
        float waterSpec = specular(-lDirection, waterNormal, viewVector);
        color += clamp(waterSpec, 0.0, 1.0) * lightIntensity;
    }
}

void VoxelPlanetRender(vec3 viewVector, vec3 positionOS, out vec3 color, out vec3 hitPos){
    //voxelization things
    //https://medium.com/@calebleak/raymarching-voxel-rendering-58018201d9d6
    float gridHalfSize = floor(_GridHalfSize);
    vec3 ro = positionOS * gridHalfSize;
    vec3 pos = floor(ro);
    
    vec3 rd = viewVector;
	vec3 ri = 1.0/rd;
	vec3 rs = sign(rd);
	vec3 dis = (pos-ro + 0.5 + rs*0.5) * ri;
	
	float res = -1.0;
	vec3 mm = vec3(0.0);
	for( int i=0; i<128; i++ ) 
	{
        float distCenter = length(pos / gridHalfSize);
		if( planetNoise(pos / gridHalfSize) * step(distCenter, _PSWaterHeight + _PSMaxHeightOffset) >0.1 ) { 
            res=1.0; break; 
        }
		mm = step(dis.xyz, dis.yzx) * step(dis.xyz, dis.zxy);
		dis += mm * rs * ri;
        pos += mm * rs;
	}

	vec3 nor = mix(-mm*rs, calcPlanetNormal(pos / gridHalfSize), 0.01); //-mm*rs;
	vec3 vos = pos;
	
    // intersect the cube	
	vec3 mini = (pos-ro + 0.5 - 0.5*vec3(rs))*ri;
	float t = max ( mini.x, max ( mini.y, mini.z ) );

    //planetShading
    float hitDistance = t*res;
    bool hitSurface = t*res >= 0.0;
    vec3 surfaceHitPosition = (ro + rd * hitDistance) / gridHalfSize;

    planetShading(hitSurface, positionOS, viewVector, surfaceHitPosition, pos/gridHalfSize, nor, true, color, hitPos);
}

void PlanetRenderRaymarch(vec3 viewVector, vec3 positionOS, out vec3 planetColor, out vec3 planetHitPos){

    //Normal ray march
    float stepSize = _PlanetSurfaceWaterStepSize;

    //Sample distance noise
    vec3 uvMask = SpherePlanarMapping(positionOS, _CylinderRad, _CylinderHeight, 1.0);
    float noiseValue = unity_noise_randomValue(uvMask.xy) + unity_noise_randomValue(uvMask.yx + 12231.23123);
    noiseValue = noiseValue/2.0;
    //Starting raymarch position
    vec3 currentPosition = positionOS + viewVector * mix(0.0, stepSize, noiseValue);
    
    vec3 pColor = vec3(-1.0,0.0,0.0);//No initersetction
    bool hitWater = false;
    bool hitSurface = false;

    for(int i = 0; i < int(floor(_PlanetSurfaceWaterMaxStepCount)); i ++){
        float cDist = length(currentPosition);
        
        if(cDist > _PSWaterHeight + _PSMaxHeightOffset * 1.0) break; //Plannet not hit surface
        
        if(cDist < _PSWaterHeight && !hitWater){
            hitWater = true;
        }

        float planetSample = planetNoise(currentPosition);
            
        if(planetSample > 0.1){
            hitSurface = true;
            break;
        }

        currentPosition += viewVector * stepSize;
    }

    if(!hitWater && !hitSurface){
        planetColor = vec3(-1,0,0);
        planetHitPos = vec3(0.0);
    }else if(!hitWater && hitSurface){
        vec3 planetNormal = -calcPlanetNormal(currentPosition);

        float lightOcclusion = 1.0;
        if(length(currentPosition) < _CloudMidDistance){
            SampleCloudShadowPlanet(currentPosition, lDirection, lightOcclusion);
            lightOcclusion = mix(1.0, lightOcclusion,_CloudTransparency);
        }
        float lightIntensity = mix(_SurfaceMinLight, 1.0, clamp(dot(planetNormal, lDirection), 0.0, 1.0) * lightOcclusion);
        float hightColorInterp = smoothstep(_PSWaterHeight, _PSWaterHeight + _PSMaxHeightOffset, length(currentPosition));
        
        pColor = mix(_PlanetColor1.xyz, _PlanetColor2.xyz, vec3(hightColorInterp)) * lightIntensity;
        planetHitPos = currentPosition;
    }else if(hitWater){
        float waterMaterial = 0.0;
        vec2 waterIntersections = sphIntersect(positionOS, viewVector, vec3(0,0,0), _PSWaterHeight);
        vec3 waterHitPosNear = positionOS + viewVector * min(waterIntersections.x, waterIntersections.y);
        vec3 waterHitPosFar = positionOS + viewVector * max(waterIntersections.x, waterIntersections.y); 

        if(hitSurface){
            waterMaterial = length(currentPosition*100.0 - waterHitPosNear*100.0);
        }else{
            waterMaterial = length(waterHitPosNear*100.0 - waterHitPosFar*100.0);
        }//_WaterColorSurface
        //waterMaterial;
        vec3 n1 = noised(normalize(waterHitPosNear) * _WaterNormalScale).yzw;
        vec3 rotatedHitPos = vec3(0.0);
        Unity_RotateAboutAxis_Radians_float(waterHitPosNear, vec3(0.0,1.0,0.0), iTime * _WaterMoveSpeed, rotatedHitPos);
        vec3 n2 = noised(normalize(rotatedHitPos) * _WaterNormalScale).yzw;
        
        vec3 waterNormal = normalize( ((n1 + n2) *_WaterNormalStrength / 2.0) + normalize(waterHitPosNear));

        float lightOcclusion= 1.0;
        if(length(waterHitPosNear) < _CloudMidDistance){
            SampleCloudShadowPlanet(waterHitPosNear, lDirection, lightOcclusion);
            lightOcclusion = mix(1.0, lightOcclusion,_CloudTransparency);
            lightOcclusion = mix(_SurfaceMinLight, 1.0, lightOcclusion);
        }

        waterMaterial = smoothstep(_WaterMaterialSmoothStep.x, _WaterMaterialSmoothStep.y, waterMaterial);
        planetHitPos = waterHitPosNear;

        float lightIntensity = clamp(dot(waterNormal, lDirection), 0.0, 1.0) * lightOcclusion;
        pColor = mix(_WaterColorDepth.xyz, _WaterColor.xyz, vec3(waterMaterial)) * mix(_WaterSurfaceMinLight,1.0, lightIntensity);// * //mix(minLight,1, );//exp(-waterMaterial * 20);
        
        float waterSpec = specular(-lDirection, waterNormal, viewVector);
        pColor += clamp(waterSpec, 0.0, 1.0) * lightIntensity;
    }   
    planetColor = pColor;
}

void main() {
    vec3 posWS = (modelMatrixFrag * vec4(vPosition, 1.0)).xyz;
    vec3 viewVecNorm = normalize(posWS - cameraPosition);

    vec2 sInter = sphIntersect(vPosition, viewVecNorm, vec3(0,0,0), _PSWaterHeight + _PSMaxHeightOffset);
    bool hitPlanet = sInter.x >= 0.0;
    
    float cloudInterp;
    vec3 cloudHitPos;
    cloudRender(viewVecNorm, vPosition, cloudInterp, cloudHitPos);
    bool cloudHit = cloudInterp < 0.0 ? false : true;

    float posterizedCloudInterp = _CloudsPosterize && _CloudsPosterizeCount >=2.0 ? floor(cloudInterp * _CloudsPosterizeCount) /(_CloudsPosterizeCount - 1.0) : cloudInterp;
    float cloudPlanetOclussion = 1.0;
    
    if(cloudHit){
        vec2 cloudPlanetInt = sphIntersect(cloudHitPos, lDirection, vec3(0,0,0), _PSWaterHeight + _PSMaxHeightOffset);
        cloudPlanetOclussion = cloudPlanetInt.x < 0.0 ? 1.0 : 0.0;
    }
    vec3 fCloudColor = mix(_CloudColor1, _CloudColor2, vec3(posterizedCloudInterp));

    vec2 atmosphereIntersec = sphIntersect(vPosition, viewVecNorm, vec3(0,0,0), 1.0);
    float atmosphereDepth = atmosphereIntersec.y - atmosphereIntersec.x;
    atmosphereDepth = InvLerp(0.0, 2.0, atmosphereDepth);
    atmosphereDepth = pow(atmosphereDepth, _AmbientPower);

    /*if(!hitPlanet){
        vec3 fColor = (cloudInterp < 0.0 ? vec3(0.0) : fCloudColor * _CloudTransparency) + _AmbientColor * atmosphereDepth;
        float fAlpha = cloudInterp < 0.0 ? atmosphereIntersec.y : max(atmosphereIntersec.y, _CloudTransparency) ;
        gl_FragColor = vec4(fColor, fAlpha);//cloudHit ? vec4(fCloudColor,1) : vec4(0.0);
    }else{*/

        vec3 planetInterPoint = vPosition + viewVecNorm * sInter.x;
        vec3 rpColor = vec3(0,0,0);
        vec3 planetHitPos = vec3(0,0,0);

        if(_EnableVoxelizer){
            VoxelPlanetRender(viewVecNorm, vPosition, rpColor, planetHitPos);
        }else{
            PlanetRenderRaymarch(viewVecNorm, planetInterPoint, rpColor, planetHitPos);
        }

        vec3 fColor = vec3(0.0);
        float fAlpha = 0.0;

        if(rpColor.x < 0.0){
            fColor = (cloudInterp < 0.0 ? vec3(0.0) : fCloudColor * _CloudTransparency) + _AmbientColor * atmosphereDepth;
            fAlpha = cloudInterp < 0.0 ? atmosphereDepth : max(atmosphereDepth, _CloudTransparency) ;
        }else{
            vec3 vToPlanet = planetHitPos - vPosition;
            vec3 vToCloud = cloudHitPos - vPosition;
            fColor = cloudInterp < 0.0 ? rpColor : dot(vToPlanet, vToPlanet) < dot(vToCloud, vToCloud) ? rpColor : mix(rpColor, fCloudColor, _CloudTransparency);
            fColor = clamp(fColor, vec3(0.0), vec3(1.0)) + _AmbientColor * atmosphereDepth;
            fAlpha = 1.0;
        }

        gl_FragColor = vec4(fColor, fAlpha);
    //}
}