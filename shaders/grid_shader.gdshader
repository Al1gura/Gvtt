shader_type spatial;
render_mode unshaded, depth_test_disabled, blend_mix;

// Gvtt 地面网格 shader —— 多级网格自动换档 + 平滑淡入淡出。
// 依据：godotshaders.com "infinite-not-quite-zoom-grid"(CC0)的"log 选档+三档同时算+transition mix"思路，
//   从 canvas_item 改成 spatial(3D 地面 PlaneMesh)版。核心逻辑一字保留，坐标换算适配 3D。
// 效果(用户要的最终视觉)：
//   拉近 → 细格可见；拉远 → 细格平滑淡出，粗格顶上当最细；再拉远 → 粗格淡出，更粗格顶上。
//   过渡是连续透明度变化，不硬切。线粗细屏幕恒定。原点轴线始终在。
// 原理：每像素覆盖多少地面 = fwidth(coord)。取对数除以 log(div_per_level) → round 取整得"第几档"。
//   space_mult = pow(div_per_level, 档号) → 当前该用的网格间距倍数。
//   transition = clamp((对数 - round) * 2 + 0.5, 0, 1) → 0~1 平滑过渡值，在两档之间连续变。
//   细档颜色 mix(细分色, 背景/透明, transition) 淡出；粗档 mix(主色, 细分色, transition) 淡入。
// 挂在 GridOverlay(第二层 PlaneMesh)上，y 抬高 0.02 避免与纹理层 z-fighting；
// 不画线处 alpha=0 透出下层纹理地面。

uniform float grid_size = 100.0;       // 地面边长(米)，跟 main.gd grid_size 一致
uniform float base_step = 1.0;       // 基准格间距(米)，最细档 = 这么多米一格
uniform int div_per_level = 5;        // 每档细分倍数(5 = 每档差5倍：1米/5米/25米/125米…)
uniform float grid_spacing_px = 50.0; // 目标格在屏幕上占多少像素(触发换档的阈值，越小越早换粗档)
uniform vec4 major_color : source_color = vec4(0.85, 0.85, 0.95, 0.9); // 当前档 偏白
uniform vec4 minor_color : source_color = vec4(0.5, 0.5, 0.6, 0.45);  // 更细档 灰
uniform vec4 axis_x_color : source_color = vec4(0.95, 0.35, 0.35, 1.0); // X 轴 红
uniform vec4 axis_z_color : source_color = vec4(0.35, 0.45, 0.95, 1.0); // Z 轴 蓝
uniform float line_px = 1.5;           // 线宽(屏幕像素)，所有线统一粗细

// 算某坐标到最近"间距 step 网格线"的距离场：0 在线上、step/2 在格中央。
float grid_line(float coord, float step) {
	return abs(fract(coord / step - 0.5) - 0.5) * step;
}

// 算某间距 step 的网格线强度(0~1)，用屏幕恒定线宽 lw 抗锯齿。
float grid_strength(float coord, float step, float lw) {
	float d = grid_line(coord, step);
	return 1.0 - smoothstep(0.0, lw, d);
}

void fragment() {
	// UV 是 0-1，PlaneMesh 默认 UV 映射到整个面。乘 grid_size 得地面米坐标。
	float coord_x = UV.x * grid_size;
	float coord_z = UV.y * grid_size;

	// 每像素覆盖多少地面米数(正交相机下全场恒定，透视下远处大近处小)。
	float px_x = fwidth(coord_x);
	float px_z = fwidth(coord_z);
	float px = max(px_x, px_z);
	float lw = line_px * px;

	// 自动选档：把"每像素覆盖多少米"取对数、除以 log(div_per_level)、round 取整 → 第几档。
	// grid_spacing_px 是目标：1 格在屏幕上占 grid_spacing_px 像素时该刚好是某档。
	// base_step * space_mult = 当前档的间距(米)。拉近 space_mult 小→细格，拉远大→粗格。
	float d_log = log(px / base_step * grid_spacing_px) / log(float(div_per_level));
	float rounded_log = round(d_log);
	float space_mult = pow(float(div_per_level), rounded_log);
	float spacing = base_step * space_mult;

	// 三档同时算"这像素在不在线上"：当前档、更细一档(÷div)、更粗一档(×div)。
	float on_grid = max(grid_strength(coord_x, spacing, lw), grid_strength(coord_z, spacing, lw));
	float on_subgrid = max(grid_strength(coord_x, spacing / float(div_per_level), lw), grid_strength(coord_z, spacing / float(div_per_level), lw));
	float on_supgrid = max(grid_strength(coord_x, spacing * float(div_per_level), lw), grid_strength(coord_z, spacing * float(div_per_level), lw));

	// transition：0~1 平滑过渡值。在两档中间(对数的小数部分)连续变。
	// =0 时在档上正好，=1 时在两档正中间。用来 mix 颜色做淡入淡出。
	float transition = clamp((d_log - rounded_log) * 2.0 + 0.5, 0.0, 1.0);

	// 细档(subgrid)颜色：过渡时从 minor_color 淡向透明(淡出)。
	// 粗档(supgrid)是更粗的备用线，过渡时从 major 淡向 minor(淡入顶上当细档)。
	// 当前档(grid)是主力，过渡时从 major 往 minor 滑(准备让位给 supgrid)。
	vec3 sub_col = mix(minor_color.rgb, major_color.rgb * 0.0, transition); // 细档淡出→透明色
	float sub_a = mix(minor_color.a, 0.0, transition) * on_subgrid;
	vec3 grid_col = mix(major_color.rgb, minor_color.rgb, transition);   // 当前档过渡色
	float grid_a = major_color.a * on_grid;

	// 合成当前档+细档：细档有强度就叠上来(拉近时细格可见)，没强度就只有当前档。
	vec3 out_rgb = mix(grid_col, sub_col, on_subgrid);
	float out_a = max(grid_a, sub_a);

	// 更粗档(supgrid)：拉远到当前档快淡出时，更粗档淡入顶上。
	// supgrid 的颜色：过渡时从 major 往 major*0.7 滑(粗档线稍微暗一点区分)。
	vec3 sup_col = mix(major_color.rgb * 0.7, major_color.rgb, transition);
	float sup_a = major_color.a * on_supgrid * (1.0 - transition); // 拉远(transition→1)时 sup 才显
	if (sup_a > out_a) {
		out_rgb = sup_col;
		out_a = sup_a;
	}

	// 轴线：穿过原点，始终在，不被换档影响。
	// 地面以中心为原点(UV 0.5 处 = 米坐标 grid_size/2)，换算成"以原点为中心"的坐标。
	float cx = coord_x - grid_size * 0.5;
	float cz = coord_z - grid_size * 0.5;
	float axis_lw = lw * 1.5;  // 轴线比主线粗一点
	float axis_x = 1.0 - smoothstep(0.0, axis_lw, abs(cz));  // X 轴 = z=0 那条
	float axis_z = 1.0 - smoothstep(0.0, axis_lw, abs(cx));  // Z 轴 = x=0 那条
	if (axis_x > 0.0) {
		out_rgb = axis_x_color.rgb;
		out_a = axis_x * axis_x_color.a;
	}
	if (axis_z > 0.0) {
		out_rgb = axis_z_color.rgb;
		out_a = axis_z * axis_z_color.a;
	}

	ALBEDO = out_rgb;
	ALPHA = out_a;
}
