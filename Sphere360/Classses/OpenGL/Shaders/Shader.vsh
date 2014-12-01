//
//  Shader.vsh
//  StockOpenGL
//
//  Created by David Sweetman on 10/11/12.
//

attribute vec4 a_position;
attribute vec2 a_textureCoord;

uniform mat4 u_modelViewProjectionMatrix;

varying lowp vec2 v_texCoord;

void main()
{
    v_texCoord = a_textureCoord;
    gl_Position = u_modelViewProjectionMatrix * a_position;
}
