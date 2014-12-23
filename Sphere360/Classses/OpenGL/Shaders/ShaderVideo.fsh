

varying lowp vec2 v_texCoord;
precision mediump float;

uniform sampler2D SamplerUV;
uniform sampler2D SamplerY;
uniform mat3 colorConversionMatrix;

void main()
{
    mediump vec3 yuv;
	lowp vec3 rgb;
    
    // Subtract constants to map the video range start at 0
    yuv.x = (texture2D(SamplerY, v_texCoord).r - (16.0/255.0));
    yuv.yz = (texture2D(SamplerUV, v_texCoord).ra - vec2(0.5, 0.5));
    
    rgb =   yuv*colorConversionMatrix;
    
    gl_FragColor = vec4(rgb,1);

}
