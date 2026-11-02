const tokenUrl = "../../design-systems/harmonytavern/tokens/rpg-themes.json";
const assetRoot = "assets/";
const details = {
  rpg_journal: { number:"01", subtitle:"羊皮纸 / 古铜 / 墨绿", title:"故事，有了纸页的温度。", material:"羊皮纸 · 细密纸纹", shape:"铜线收边 · 手札页角", accent:"古铜与森林绿", caption:"PARCHMENT & AGED BRASS" },
  rpg_sakura: { number:"02", subtitle:"和纸 / 朱印 / 靛青", title:"在留白里，听见旅途。", material:"和纸 · 淡墨花影", shape:"薄线折页 · 小圆角", accent:"朱印与暮色靛青", caption:"WASHI & VERMILION" },
  rpg_pixel: { number:"03", subtitle:"掌机 / 方格 / 森林", title:"小小的像素，辽阔的世界。", material:"像素地景 · 方格像素", shape:"直角界面 · 双线边框", accent:"森林绿与旧金", caption:"PIXEL WORLDS & OLD GOLD" },
  rpg_dungeon: { number:"04", subtitle:"石壁 / 锻铁 / 余烬", title:"暗处的故事，也有微光。", material:"风化石壁 · 克制暗纹", shape:"铁框切角 · 锻造边线", accent:"余烬与暖金", caption:"IRON, STONE & EMBERS" }
};
let themes = [];
let themeId = "rpg_journal";
let mode = "light";
let page = "chat";
let toastTimer;
const pages = {
  chat: { title:"聊天", subtitle:"让故事继续", action:"创建聊天" },
  characters: { title:"角色", subtitle:"遇见另一种可能", action:"新建角色" },
  library: { title:"资料库", subtitle:"整理故事的每一页", action:"添加资料" },
  settings: { title:"设置", subtitle:"让酒馆更像你的世界", action:"刷新设置概览" }
};
const icon = (name, extra = "") => '<span class="icon '+extra+'" data-icon="'+name+'" aria-hidden="true"></span>';
function hydrateIcons() {
  document.querySelectorAll("[data-icon]").forEach(element => element.style.setProperty("--icon", 'url("assets/'+element.dataset.icon+'.svg")'));
}
function notify(message) {
  const toast = document.querySelector("#toast");
  toast.textContent = message; toast.classList.add("visible");
  clearTimeout(toastTimer); toastTimer = setTimeout(() => toast.classList.remove("visible"), 2700);
}
function card(name, copy, initial) {
  return '<article class="character-card"><span class="portrait">'+initial+'</span><div><h3>'+name+'</h3><p>'+copy+'</p></div>'+icon("icon_chevron")+'</article>';
}
function renderPage() {
  const current = pages[page];
  document.querySelector("#app-title").textContent = current.title;
  document.querySelector("#app-subtitle").textContent = current.subtitle;
  document.querySelector("#header-action").setAttribute("aria-label", current.action+" · 视觉演示");
  document.querySelector("#header-action").innerHTML = icon(page === "settings" ? "icon_refresh" : "icon_add");
  document.querySelectorAll("[data-page]").forEach(button => {
    if (button.dataset.page === page) button.setAttribute("aria-current","page"); else button.removeAttribute("aria-current");
  });
  const sampleLabel = '<div class="section-kicker"><span>视觉演示 / 示例内容</span><span>HARMONY TAVERN</span></div>';
  const content = {
    chat: sampleLabel+'<article class="chat-hero"><div class="hero-top"><span class="portrait">艾</span><div><h3>艾琳</h3><small>DeepSeek · 故事示例</small></div></div><p class="bubble">酒馆门上的风铃轻轻响起。她合上手里的地图，抬头看向你。<br>「旅人，你也在寻找北方的星塔吗？」</p><p class="bubble you">先给我讲讲，这张地图的故事。</p><div class="composer"><input aria-label="示例消息" placeholder="说点什么…" maxlength="120"><button type="button" data-demo="仅展示消息按钮样式，未发送请求" aria-label="预览发送按钮">'+icon("icon_send")+'</button></div></article><div class="section-kicker"><span>最近对话</span><button type="button" data-demo="预览中显示两段示例对话">查看全部</button></div>'+card("北方的星塔","「下一站，我们去哪里？」","星")+card("雾林来信","故事停在一封未拆的信上。","林"),
    characters: sampleLabel+'<div class="preview-search">'+icon("icon_more")+'<span>搜索角色名称或描述</span></div><div class="character-gallery"><article class="featured-character"><div class="character-art"></div><div class="featured-info"><span>角色示例</span><h3>艾琳</h3><p>随身带着地图的旅人，<br>正在寻找北方的星塔。</p></div></article></div>'+card("林间守望者","守着一段很久以前的约定。","林")+card("无名骑士","盔甲上留着旅途的风霜。","骑"),
    library: sampleLabel+'<div class="library-banner"><span>'+icon("nav_library")+'</span><div><h3>让灵感，有迹可循</h3><p>世界、角色与故事的细节，归于此处。</p></div></div><div class="library-grid"><article class="library-tile">'+icon("icon_book")+'<h3>世界书</h3><p>背景、设定与故事线索</p></article><article class="library-tile">'+icon("nav_character")+'<h3>角色卡</h3><p>相遇之前，先了解彼此</p></article><article class="library-tile">'+icon("icon_inventory")+'<h3>创作资源</h3><p>图片、声音与文件</p></article><article class="library-tile">'+icon("icon_save")+'<h3>备份与恢复</h3><p>为故事留一份副本</p></article></div>',
    settings: sampleLabel+'<div class="provider-overview">'+icon("icon_cloud")+'<div><span>模型与连接</span><h3>服务商管理</h3><p>连接 AI 服务，为故事选择合适的模型</p></div>'+icon("icon_chevron")+'</div><div class="section-kicker"><span>外观与偏好</span></div>'+settingsRow("icon_appearance","显示与外观","阅读配色、玻璃质感与动态效果")+settingsRow("icon_settings","通用偏好","应用行为、性能与网络偏好")+'<div class="section-kicker spaced"><span>身份与创作</span></div>'+settingsRow("nav_character","用户设定管理","头像、昵称与人设")+settingsRow("icon_edit","回复预设","保存不同角色与故事的回应风格")+'<div class="section-kicker spaced"><span>模型与连接</span></div>'+settingsRow("icon_key","密钥管理","管理模型服务凭据")
  };
  document.querySelector("#page-content").innerHTML = content[page];
  hydrateIcons();
  renderStatus();
}
function settingsRow(iconName, title, subtitle) {
  return '<div class="settings-row">'+icon(iconName)+'<div><strong>'+title+'</strong><small>'+subtitle+'</small></div>'+icon("icon_chevron")+'</div>';
}
function renderStatus() { document.querySelector("#preview-state").textContent = (mode === "dark" ? "夜间" : "日间")+" / "+pages[page].title; }
function renderTheme() {
  const theme = themes.find(item => item.id === themeId);
  const copy = details[themeId];
  const colors = theme[mode];
  document.body.dataset.theme = themeId;
  document.body.dataset.mode = mode;
  const body = document.body.style;
  const mapping = { background:"--paper", surface:"--surface", surfaceHigh:"--surface2", accent:"--accent", ornament:"--accent2" };
  for (const [token, css] of Object.entries(mapping)) body.setProperty(css, colors[token]);
  body.setProperty("--radius",theme.radius+"px");
  body.setProperty("--theme-border",theme.borderWidth+"px");
  body.setProperty("--theme-art",'url("'+assetRoot+theme.art+'")');
  body.setProperty("--theme-texture",'url("'+assetRoot+theme.id+'_texture.png")');
  body.setProperty("--theme-frame",'url("'+assetRoot+theme.id+'_frame.png")');
  body.setProperty("--ink",mode === "dark" ? "#F0EADF" : "#2B2924");
  body.setProperty("--muted",mode === "dark" ? "#C0B6A6" : "#655D50");
  body.setProperty("--line",colors.ornament+"66");
  document.querySelector("#theme-title").textContent = theme.label;
  document.querySelector("#theme-description").textContent = theme.description;
  document.querySelector("#theme-number").textContent = copy.number;
  document.querySelector("#theme-english").textContent = theme.kicker;
  document.querySelector("#material-title").textContent = copy.title;
  document.querySelector("#detail-material").textContent = copy.material;
  document.querySelector("#detail-shape").textContent = copy.shape;
  document.querySelector("#detail-accent").textContent = copy.accent;
  document.querySelector("#material-caption").textContent = copy.caption;
  const image = document.querySelector("#material-image");
  image.src = assetRoot+theme.art;
  image.alt = theme.label+"主题素材";
  document.querySelector("#palette").innerHTML = [colors.background,colors.surface,colors.surfaceHigh,colors.accent,colors.ornament].map(color => '<i title="'+color+'" style="background:'+color+'"></i>').join("");
  document.querySelector("#color-values").textContent = [colors.background,colors.accent,colors.ornament].join(" / ");
  document.querySelectorAll("[data-theme-choice]").forEach(button => button.setAttribute("aria-pressed",String(button.dataset.themeChoice === themeId)));
  document.querySelectorAll("button[data-mode]").forEach(button => button.setAttribute("aria-pressed",String(button.dataset.mode === mode)));
  renderStatus();
}
document.addEventListener("click", event => {
  const themeButton = event.target.closest("[data-theme-choice]");
  const modeButton = event.target.closest("button[data-mode]");
  const pageButton = event.target.closest("[data-page]");
  const demoButton = event.target.closest("[data-demo]");
  if (themeButton) { themeId = themeButton.dataset.themeChoice; renderTheme(); }
  if (modeButton) { mode = modeButton.dataset.mode; renderTheme(); }
  if (pageButton) { page = pageButton.dataset.page; renderPage(); }
  if (demoButton) notify(demoButton.dataset.demo);
  if (event.target.closest("#header-action")) notify(pages[page].action+" · 仅展示视觉，未修改应用数据");
});
fetch(tokenUrl).then(response => { if (!response.ok) throw new Error("Theme data unavailable"); return response.json(); }).then(data => {
  themes = data.themes;
  document.querySelector("#theme-choices").innerHTML = themes.map(theme => '<button type="button" class="theme-choice" data-theme-choice="'+theme.id+'" aria-pressed="false"><strong>'+theme.label+'</strong><small>'+details[theme.id].subtitle+'</small><span class="swatches" aria-hidden="true"><i style="background:'+theme.light.background+'"></i><i style="background:'+theme.light.accent+'"></i><i style="background:'+theme.dark.background+'"></i></span></button>').join("");
  renderPage(); renderTheme();
}).catch(error => {
  document.querySelector("#theme-description").textContent = "请通过 OpenDesign 预览服务器打开此页面。";
  notify(error.message);
});
