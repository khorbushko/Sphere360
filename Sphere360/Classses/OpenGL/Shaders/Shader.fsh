//
//  Shader.fsh
//  StockOpenGL
//
//  Created by David Sweetman on 10/11/12.
//

uniform sampler2D u_Sampler;

varying lowp vec2 v_texCoord;

void main()
{
    gl_FragColor = texture2D(u_Sampler, v_texCoord);
}
