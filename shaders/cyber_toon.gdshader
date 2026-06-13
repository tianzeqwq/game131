// todo: 预留 后面删
shader_type spatial;

// 渲染模式：保留 ambient 让编辑器 Viewport 也能预览颜色
// （ambient_light_disabled 会导致编辑器里 GL Compatibility 模式下全黑）
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

// ═══════════════════════════════════════════════
// 赛博朋克色盘（三段式：暗部 / 中间调 / 受光面）
// ═══════════════════════════════════════════════
uniform vec3 color_shadow   : source_color = vec3(0.004, 0.141, 0.298); // #01244c 极暗蓝黑（暗部）
uniform vec3 color_midtone  : source_color = vec3(0.000, 0.376, 0.573); // #006092 钢蓝（中间调）
uniform vec3 color_lit      : source_color = vec3(0.600, 0.670, 0.850); // 亮部：冷灰蓝，防止白色过曝

// 物体自身的固有色（在Inspector里按材质设置）
uniform vec3 albedo_color   : source_color = vec3(1.0, 1.0, 1.0);

// 色区阈值：只看角度（NdotL），跟距离无关
uniform float shadow_threshold  : hint_range(0.0, 1.0) = 0.2;
uniform float midtone_threshold : hint_range(0.0, 1.0) = 0.6;

// 红色轮廓光由场景中的 OmniLight（颜色 #ff3533）提供，无需在 shader 里硬编码

void fragment() {
	ALBEDO = albedo_color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	if (NdotL <= 0.0) return;

	// ── 色区：纯角度判断，跟距离无关 ──────────────────────────────
	// 这样灯在任意距离内只要"朝向对了"就能显示正确的颜色区域
	float t1 = smoothstep(shadow_threshold - 0.05, shadow_threshold + 0.05, NdotL);
	float t2 = smoothstep(midtone_threshold - 0.05, midtone_threshold + 0.05, NdotL);

	vec3 palette = mix(color_shadow, color_midtone, t1);
	palette      = mix(palette, color_lit, t2);

	// ── 灯光颜色：clamp 去掉 energy 溢出（energy=3 → LIGHT_COLOR.r≈3，会变白）
	// clamp 后只保留色相，不让高能量灯把受光面烧成白色
	vec3 light_tint = clamp(LIGHT_COLOR, 0.0, 1.0);
	vec3 colored    = mix(palette, palette * light_tint, t1);

	// ── ATTENUATION 只做距离渐隐，不参与色区判断 ─────────────────
	DIFFUSE_LIGHT += colored * albedo_color * ATTENUATION;
}