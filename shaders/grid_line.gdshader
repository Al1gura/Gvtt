shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_test_disabled;

// Gvtt 网格线 shader —— 极简版。
// 几何体已经在 CPU 端算好了屏幕恒定宽度（GDScript 端 bake 进顶点位置），
// shader 只负责输出顶点颜色和 alpha 淡出。
// 不涉及任何 fwidth/屏幕空间/对数运算。

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
