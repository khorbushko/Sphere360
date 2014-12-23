

attribute vec4 a_position;
attribute vec2 a_textureCoord;

uniform mat4 u_modelViewProjectionMatrix;

varying lowp vec2 v_texCoord;

void main()
{
    v_texCoord = vec2(a_textureCoord.s, 1.0 - a_textureCoord.t);
    gl_Position = u_modelViewProjectionMatrix * a_position;
}
