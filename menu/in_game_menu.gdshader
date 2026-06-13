shader_type canvas_item;

// 控制大世界画面的背景模糊强度
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
// 控制背景调色（暗度与赛博科幻感色调，这里默认用深邃蓝黑）
uniform vec4 tint_color : source_color = vec4(0.05, 0.08, 0.12, 0.65);

// 抓取屏幕背后的图像
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // 1. 进行多重采样模糊
    vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);
    
    // 2. 将模糊后的背景与我们的半透明深色进行线性混合
    COLOR = mix(color, tint_color, tint_color.a);
}