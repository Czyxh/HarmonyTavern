Title: 底部页签-设计-应用设计-控件-导航类-底部页签

URL Source: https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/bottomtab-0000001956787789

Markdown Content:
移动设备中最常见的应用级导航控件，开发相关描述请参考 [Tabs/BottomTabBarStyle](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabs) 文档。

![Image 1: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/51/v3/OZSG8uHQRmWqV49jiIs9OQ/zh-cn_image_0000001956811437.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=15F4D4F85FF771273680228BC3FFB2C4E4B92F5891E228EAEFF4DE0A2A9B121F)

## 如何使用

**底部页签是一种常见的界面导航结构，通常位于应用程序屏幕的底部。**通过点击页签项，用户可以快捷地访问应用的不同分类界面。根据使用场景及设备类型，底部页签将会呈现为不同设计样式。在HarmonyOS 6.1版本之后，底部页签分为了两种呈现方式，平铺式和悬浮式。平铺式底部页签是撑满界面底部或侧边，适配炫彩透光模糊材质的样式，悬浮式底部页签是悬浮在页面之上，适配沉浸光感材质的样式。

**避让系统导航条。**在 HarmonyOS Next 之后的系统界面底部会固定显示导航条，因此，在自定义底部页签样式的时候需注意避让导航条区域，避免应用的文本或图标信息与导航条重叠。控件在默认情况下会避让导航条，平铺式的底部页签组件整体高度会扩展至导航条区域，但底部页签的按键热区与导航条热区互相独立。平铺式底部页签默认高度为 48vp，悬浮式底部页签默认高度为56vp，如果开发者需要自定义底部页签的样式和结构，可以通过 [expandSafeArea](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-universal-attributes-expand-safe-area) 了解能力规格。

![Image 2: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/7a/v3/SQalNUQgQSCp6Sqha7ZXdA/zh-cn_image_0000002156760589.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=BC8D98ED5BA90363345DD3A9F6B8B9A892365FB75848BC4EE43ED4C45150E3E0)

**避免大量的使用页签数量。**通常情况下一个应用程序会包含 3-5 个同等重要的功能模块，这些模块之间彼此互斥。过多页签数量会增加复杂度并缩减单个页签的可点击区域，造成基础功能上的使用障碍，同时增加用户的认知复杂度。一般情况选择 4 个以下页签数量，针对特征性的运营设计可以使用 4+1 的模式进行自定义，即四个基础功能页签和一个运营性页签。

![Image 3: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/88/v3/knzgjqo1Rl6vj66_hK-dAg/zh-cn_image_0000002608231151.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=ED0E191EF3D36CF5B4455E2C072FFE5F0A14D22EC6D9B78EA2EDB08C14793A66)![Image 4: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/0/v3/wKs3mPZwSYWs1uM9ew494w/zh-cn_image_0000002608071233.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=4AB69BF01E5A7AD04AB788B019620BD8341150C7878DC8610E314F7AABBDEFA3)
**悬浮式默认页签样式**

图标大小默认为 24*24vp**悬浮式自定义运营页签样式**

图标居中对齐显示，运营资源可向上出血 4 vp

![Image 5: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/10/v3/_Bs1iJajRAyFUKbpEqd59A/zh-cn_image_0000002156683005.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=FD606F8623B0AD28A89DE9CAFFD7B752F6D42ECB9D32F5E0FBC0A61EB05EAE68)![Image 6: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/0c/v3/yOg3BBKwQByCQQrv9okLyA/zh-cn_image_0000002121402754.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=2B11526D3B735802A181FBF9C3ED09175AF516732778D5AB6BB09DD147B09012)
**平铺式默认页签样式**

图标大小默认为 24*24vp**平铺式自定义运营页签样式**

图标居中对齐显示，保证上下安全间距为 4vp

**页签标签应使用简洁的文字或图标表达，让用户一目了然。**被激活的页签应有明确的视觉反馈，如使用品牌高亮色显示，或增加激活动效提升设计细节和品质感。避免在页签中放置次要或高级功能入口，以免分散用户注意力，对于未激活的页签应当弱化展示效果，通过降低透明度或者将颜色置灰来对图标和文本进行处理。在文本的处理上要减少字符串的使用，在 2-4 个字符串以内明确概述页签的功能，英文和多语言场景下尽量使用一个单词或一个词组来展示。

**使用 HarmonyOS Symbol 来展示图标信息**。在底部页签中可以替换系统 [Symbol](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-basic-components-symbolglyph) 样式来更灵活的展示图标信息，这种方式更匹配文本的展示效果，同时提供点击反馈，更直接的展示界面设计的细节。开发者可以在 [HarmonyOS Symbol](https://developer.huawei.com/consumer/cn/design/harmonyos-symbol/) 开源网站上查询目前已经存在的图标样式。

## 视觉规则

### 视觉反馈

点击切换页签时需要明确的切换行为告知，若点击当前页签，界面会回滚至页面顶部或指定位置。页签在切换时，选中态有细微的点击弹跳动效，推荐使用[Symbol（BounceSymbolEffect-EffectDirection.DOWN）](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-basic-components-symbolglyph#bouncesymboleffect12)。有关底部页签展示 Symbol 能力接口和动效能力可查阅 [TabBarSymbol](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabcontent#tabbarsymbol12%E5%AF%B9%E8%B1%A1%E8%AF%B4%E6%98%8E) 开发文档。

[Video 11](https://contentcenter-videovali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_300_3/80/v3/eKEOlzpzRCSnSXNR6Uns8w/zh-cn_attachment_0000002623532671.mp4?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=6BB87508F3ACB7B71818F325B7C8400B6360F3476A489FD1F35A42B9032232F0)
Video Player is loading.

Current Time 0:00

Loaded: 0%

Duration-:-

733

在悬浮底部页签区域滑动切换页签，为避免手势冲突，不支持通过横滑内容切换底部页签。

[Video 12](https://contentcenter-videovali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_300_3/df/v3/JenhR95ySk-SenKkPWHUmQ/zh-cn_attachment_0000002593253560.mp4?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=536C7AFF337DD743BE2190D25BED4BE16B7C8BC5D0BC4F5B83E5EA9671F2B183)
Video Player is loading.

Current Time 0:00

Loaded: 0%

Duration-:-

523

### 沉浸光感

在移动应用的用户体验中，用户启动应用后第一时间感知到的首眼体验，承载着确立产品调性、建立操作预期、引导用户路径的多重职能。[沉浸光感](https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/immersivelight-0000002612101053)为底部页签组件提供更加沉浸的应用首眼体验。

![Image 7](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/74/v3/xMVIaIqPRvehX50jCvCySQ/zh-cn_image_0000002603687613.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=136E562D744903257A4748439D3F548EE493DC1BC76FBCF0C8E27D69FB2DFEE1)本节中沉浸光感图示效果部分为强档效果，并非组件的默认效果。更多沉浸光感效果请参阅：[沉浸光感](https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/immersivelight-0000002612101053)。

在之前的设计中，控件通常以不透明或高对比的方式覆盖于内容之上，形成明确的视觉截断；而沉浸光感材质通过对背景内容的折射、模糊与透射，使控件层在保持可识别性的前提下，与内容层建立视觉上的连续性。用户感知到的不再是内容与组件的割裂感，而是内容穿过控件介质的空间纵深感受，这种空间连续性显著增强了界面的整体沉浸感。

![Image 8](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/34/v3/Ta77n_X3ROCuxl1cJi68rw/zh-cn_image_0000002573008570.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=10F5045108D9B0495166F652D8A274A5D92847FC1F1B84340B368529744C426D)

**在内容滚动与界面交互过程中，通过渐变蒙层强化控件层与内容层的空间关系。**当内容区域与底部页签区域产生重叠时，过渡区域采用颜色渐变的方式，使内容向控件的过渡呈现自然的衰减而非生硬的截断，增加沉浸感的同时，减少内容区对底部页签的干扰。

与标题栏不同，底部页签的主要信息由容器承载，而标题栏存在无容器承载的重要信息内容，所以顶部采用渐变模糊增强标题信息可读，底部采用渐变颜色增强界面空间感。

![Image 9](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/af/v3/8jbvGyjfSdCtXbH0jfcxkA/zh-cn_image_0000002603687693.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=94C4DE37A1C53C3700CA195D9D78BAF54B9048CC20EB5DCA3A0D488577A04FFA)

渐变颜色层建议较底部内容最顶边高 16 vp，渐变颜色需与页面背景色保持一致。

![Image 10](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/db/v3/L1K9ZaYKRI-s27wpfGqGzw/zh-cn_image_0000002603727773.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=3FFBC6BC6124F0209C62DE4E97BA47B0C1F5F326EF920333D63CED18C11E0E35)

**为了进一步保障标题内容可读性，建议在内容复杂、色彩丰富的页面使用动态反色能力。**通常底部页签中的颜色属性有浅色模式和深色模式两种色彩配置方案，动态反色是指在底部页签下方内容与标题栏重叠情况下出现可读性问题时，底部页签中的容器材质、图标、文本等内容颜色在深浅色模式两种色彩方案中进行动态切换，以提高复杂场景中底部页签内容的可读性。

![Image 11](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/bb/v3/8-ZnhUVeROOdG8pp_ujDTw/zh-cn_image_0000002573168332.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=E7D73E7BCAB7304FD11BEAC23037DD5EBE0F21F72683F87279E2FFA8A19CB680)

**光感形变交互**

光感交互是手指触控位置与视觉效果相结合，模拟真实物理界面中触摸可发光变形事物的视觉反馈。当用户与底部页签中的按钮产生交互时，指尖位置被定义为动态光源和材质受力点，向周围材质表面投射光晕，照亮容器边缘，光照强度随距离衰减，同时使容器向手指位置形变。这一交互反馈使操作行为本身成为界面光学环境的变化源，用户通过视觉即可感知交互的进程与状态。

![Image 12](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/70/v3/IQoZ1bttTXubx7q5vGnvXw/zh-cn_image_0000002573008708.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=40B24C5C63951EC3FCB563C354E403136462BD4816E568B37107711FADBCCAFA)不同颜色的光感效果不一致，建议使用组件提供的默认光效属性。如需修改光效颜色，建议使用低透明度，高亮度的色彩。

### 模糊材质

使用平铺式底部页签样式时，可以通过模糊材质实现更高级的视觉效果。

[Video 13](https://contentcenter-videovali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_300_3/c1/v3/QYRgwgGcTQ6ajsT_ueqBFA/zh-cn_attachment_0000002688062514.mp4?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=E08296FF5D6292B31082AE1C0FC2119BD452736CDAEA965151A818AD1802EABC)
Video Player is loading.

Current Time 0:00

Loaded: 0%

Duration-:-

62

使用 Ark UI 的底部页签控件，实现模糊效果之前需要配置底部页签 [barOverlap](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabs#baroverlap10) 属性为 true，将底部页签覆盖在内容区之上，再通过 [barBackgroundColor](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabs#barbackgroundcolor10) 和 [barBackgroundBlurStyle](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabs#barbackgroundblurstyle11) 属性结合实现，模糊材质本身已经包含一层背景色，因此 barBackgroundColor 需要设置为透明度模式，否则也会被模糊材质影响。如果你希望自定义模糊效果，可以通过 [BackgroundEffectOptions](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-universal-attributes-background#backgroundeffectoptions11) 进行对容器背景效果的自定义。

使用 HDS 底部页签控件，默认带有模糊背板属性。同时，HDS 的底部页签控件，提供了两种模糊类型：

*   背板模糊：对底部页签的背景进行均匀的模糊处理，模糊强度一致，边界清晰，用于强调控件与内容的层级分隔。
*   渐变模糊：模糊效果在空间维度上呈现渐强/渐弱的变化，模糊边界柔和，用于增强页面沉浸感。

HDS 底部页签控件开发相关描述请参阅 [HDS Tabs](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-hdstabs) 文档。

**背板模糊**

在底部页签中，背板模糊作为独立视觉层级存在，与内容层形成悬浮空间关系，适用于页面内容与底部页签产生交叠的场景。

![Image 13: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/43/v3/Upeg_j5sQ6SqtDXyx664Jw/zh-cn_image_0000002445394529.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=91804D35C0972A46527C20E7767F20F72A5C873F2A47395124A508FD1BC1CC80)

**通过提亮压暗增强色彩活力。**底部页签的背板模糊默认带有提亮压暗属性，能够激发色彩活力，提高背板通透度。

**通过分割线提高内容边界可识别性。**为避免视觉认知障碍问题，默认情况下，模糊背板上边缘带有一条 1 px 的分割线。

**通过微动效增强内容触底的暗示。**当页面内容离开底部页签区域后，默认触发模糊 & 分割线渐变隐藏，增强触底操作的心理暗示。

[Video 14](https://contentcenter-videovali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_300_3/44/v3/pAVjqFIdQki_AE0EG__I3w/zh-cn_attachment_0000002717822305.mp4?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=1DCF3BEC4F6DD3DFB9346FF3018DCA6120FFDA082769E480DE209F02375FBCD2)
Video Player is loading.

Current Time 0:00

Loaded: 0%

Duration-:-

45

**渐变模糊**

渐变模糊与页面内容的融合度更高，通过弱化视觉边界，以延展页面空间，但渐变模糊会增高页签占用面积、降低页签内容可读性，因此仅适用于部分特定场景。

![Image 14: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/3e/v3/OIEYDZvYSRisul2Pb6MihQ/zh-cn_image_0000002345408293.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=716034FE708D63BC9046E155323BF615A3BB00E5B34AA6A442CB0CE410C3B62D)

## 布局规则

### 悬浮式页签

**样式类型**

沉浸光感底部页签组件提供多种适配样式类型，包含居中布局、左右布局、上下布局形式，满足更多场景的定制化需要。左右布局和上下布局中的 MiniBar 可用于放置页面常驻且可交互的操作功能组，与 Tabs 相互结合为用户带来全新的底部页签交互体验。

![Image 15](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/3b/v3/io4IKh5HTKGlvHrhIk4D7Q/zh-cn_image_0000002605416815.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=EDEF5BB9F9EB87177BC158318DCB2F53B350EAE393870ABB5160A1D5A87A7B64)

布局样式

![Image 16](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/c/v3/nqlasz2zTsGOzMQidWwSMQ/zh-cn_image_0000002574617788.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=9E8FD9D8BD5EAD8A158E21F28247BCCBD19DDE31219AA794B640B50C21B08508)

左右布局变体![Image 17](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/bc/v3/x8L5yKX_Q4uJ5mU3-mrReQ/zh-cn_image_0000002605296875.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=B0CA8825ADD7BBFDB696E38743198D1D610DD566E1228A24FC2C56C42D41FC34)

上下布局变体

**居中布局**

底部页签由胶囊型矩形容器承载，高度统一为 56 vp。容器的宽度对内容布局的舒适度产生重要影响，所以不同的 Tabs 数量需要采用不同的宽度。由于设备众多，为适配不同的设备大小，容器宽度需要基于断点规则计算得出，不推荐设置固定的底部页签宽度，易导致部分设备或场景的体验问题。

![Image 18: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/dc/v3/k5IPrFjwTKaeTQ4_-0Z47A/zh-cn_image_0000002574790548.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=1F24EFE8DC7C434A6863C8FF18F6B810CD465320C7D85B976C27F66B1B2A2168)

宽度由计算得出，使用 [HdsTabs](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-hdstabs#hdsbarwidthrangeoptions) 组件，宽度默认基于不同断点进行自适应计算，具体断点规则请参阅开发接口 [HdsBarWidthRangeOptions](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-hdstabs#hdsbarwidthrangeoptions) 。

Tabs 容器宽度有最大值限制。当配置 Tabs 数量大于等于 5 个时，最大值限制为 360 vp，即在宽屏设备上显示的最大宽度为 360 vp；当配置 Tabs 数量为 4 个时，最大值限制为 328 vp。

![Image 19: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/e8/v3/HgXLOGHNTC26naGulgLBug/zh-cn_image_0000002574789628.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=B5F6ED66D68D23233120CE207AFA84459FABA71EDB45BD64B9E1338E19213659)

在平板设备上，建议整体放大1.15倍，在宽屏设备上提高易读性和易用性。

![Image 20: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/9c/v3/qtK4RbFJRwyBWvkQFVucVA/zh-cn_image_0000002605314329.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=D24A95FEE67E5DFA1C77AF8285E378CC9CC83BCFEB110E9FE74F0BDF45163623)

若 Tabs 配置个数为 2 个或 3 个时，则采用固定宽度，根据窗口宽度断点采用不同的宽度。

![Image 21: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/6e/v3/IyzWYFm6R-SD4QM6BNYcdg/zh-cn_image_0000002574783248.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=86BE7AB22F8DFCC802210D1566C538D31AC3B48375C79E0BEF1DE3F48EBC780D)

窗口宽度小于 600 断点时，3 个 Tabs 固定宽度 248 vp；2 个 Tabs 固定宽度 168 vp![Image 22: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/8b/v3/Ihwq-6wqTH-Rp4C5TA7N5Q/zh-cn_image_0000002574627600.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=80F845AA33A1A74FCD7EE227551E333B55793AD670D21618253E9C92899EC49F)

窗口宽度大于等于 600 断点时，3 个 Tabs 固定宽度 272 vp；2 个 Tabs 固定宽度 184 vp
![Image 23: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/84/v3/6-7xnbn3QW2-MAptWBtdxw/zh-cn_image_0000002605316545.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=C74281F8D5847C213AE709F2D101B6C98D128FE61F0BC487F7A67B73B8FB9EFF)
不推荐：窗口宽度大于等于 1440 断点时，2～3 个 Tabs 视觉体量过小，交互可操作性差，不建议使用底部页签形式。

**左右布局**

左右布局是在底部页签右侧增加一个 MiniBar 形式容器，与底部页签存在联动关系。该 MiniBar 可折叠展开，当底部页签展开时，MiniBar 折叠为圆形按钮，当 MiniBar 展开时，Tabs 折叠为圆形按钮。在多设备布局中，MiniBar 存在三种不同的布局方式。

![Image 24: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/53/v3/J7gctYTuRd2w1ZfsxQK_Mw/zh-cn_image_0000002574641692.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=10E4B801F6A28193F08BC223A8378E95E96AF768AE9964DB55826C8365F07766)

布局 A ：Tabs 和 MiniBar 整体在窗口内居中

布局 B ：展开的 Tabs 或 MiniBar 在窗口内居中，折叠后的圆形按钮位于左右两侧，距离窗口边缘 Margin 数值基于栅格断点规则

布局 C ：Tabs 和 MiniBar 分布在左右两侧，距离窗口边缘 Margin 数值。

三种不同布局形式适用的窗口断点区间不同。建议在宽度断点区间为 320～440 vp 区间使用 A 布局；440～600 vp 区间和 600～840 vp 且宽高比小于 0.8 区间使用 B 布局，600～840 且宽高比大于 0.8 区间和 840～1440 vp 宽度断点区间使用 C 布局。

![Image 25: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/cb/v3/BPtRjhziS8uxY0mPth2XkA/zh-cn_image_0000002605320931.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=6ACF0BC630DBB5DE0AB7DE1DA520AE1AB18DD82DEDCDDEA39F60551846BB8608)

MiniBar 的宽度应与 TabsBar 宽度保持一致。

![Image 26: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/04/v3/3zFsW1iQQJWD7cPEgx9ACQ/zh-cn_image_0000002574802228.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=4E2F53A3B3BFEEA5C3B965BC38F7ED55FCF9754BFC9C29E26780FCC32A213655)

**上下布局**

上下布局是结合左右布局的一种适配类型，旨在设备宽度较窄、左右布局较为拥挤的情况下使布局更加合理。建议宽度断点在 320～440 vp 区间，根据业务场景需要使用。

上下布局分为滑动前和滑动后两种状态，滑动前 MiniBar 在 TabsBar 上方，距离 TabsBar 顶部 8 vp，滑动后 切换为左右布局，此时 TabsBar 收起成为圆形按钮，MiniBar 展开。若点击 折叠后的 TabsBar 圆形按钮，则会切换回滑动前上下布局的样式。

![Image 27: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/a/v3/fLZF53j3R3Stc-l6wPV7pQ/zh-cn_image_0000002574648182.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=7C5089F927A9CB3361E1E202EB42F79460964AB2F6A5AF817B1FEE72FAF89DD6)

采用上下布局时，为保障滑动前后 TabsBar 总宽度一致，在默认情况下，滑动后的 MiniBar 有最大宽度限制，当 Tabs 配置个数为 5 个时，最大宽度限制为 264 vp，当 Tabs 配置个数为 4 个时，最大宽度限制为 296 vp

![Image 28: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/e3/v3/HE30bE_SQNe4JHiRtDEIlw/zh-cn_image_0000002605327263.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=65F5328C08F208D1DEA956C780C33D6E1A9BCF28D68BE34D82CBBD1FFAF2E48D)

**宽屏跟手**

8 栅格以上尺寸支持配置组件跟随交互手的体验，以提升宽屏设备的操作效率，单手操作时底部页签会移动到操作手的一侧。

![Image 29: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/a2/v3/uBxWZ7XTSTe3INnbrhqVGA/zh-cn_image_0000002582935124.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=06E3EBCEE342F8E95F94538C7F216C6F185F04AC7252BE1DD8B974376E351E41)

**滑动跟手隐藏**

在沉浸浏览和屏幕高度较小的设备商，为了提供更大的内容显示空间，悬浮底部页签支持设置为跟手滑动隐藏。

[Video 15](https://contentcenter-videovali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_300_3/11/v3/S-qXz-kSShWLfGXNhXWkwg/zh-cn_attachment_0000002633566286.mp4?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=710E2B1E93973CF2E11A52D1A52AD7DBAA9DC35E51CCC32A9D9AE4EE4745C48B)
Video Player is loading.

Current Time 0:00

Loaded: 0%

Duration-:-

141

### 平铺式页签

**手机设备 - 布局结构**

该布局适用于直板机竖屏、折叠机展开态横竖屏和平板竖屏，默认单个组件宽度根据个数在内容宽度内水平均分，最多允许放 5 个。文字范围在单个页签范围内两边保持安全间隔。

![Image 30: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/9/v3/jfibmcSwSY6DLV4TqqgsqA/zh-cn_image_0000001929812006.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=8389C28DF3D12B9D8095B7CCDEEC130ED606744B4B768E7A07CE016FFE6305E3)![Image 31: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/4a/v3/Gvn28NHoSfKi0CuKZphMbg/zh-cn_image_0000002121403526.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=29F8EB0DA37C9996ED06AF8B5A143EBD253AB5C9D08C09B3A33368F26325343E)

**手机设备 - 左右结构**

在一些特殊场景下，例如手机进入横屏状态，此时的屏幕显示区域处于高度较矮、宽度较宽的场景时，为了更有效的利用可展示区域，底部页签可以修改为左右布局来进行展示。可以查阅底部页签的 [LayoutMode](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabcontent#layoutmode10) 接口进行了解，配置其样式为 HORIZONTAL。需要注意，当布局修改为左右布局时，文本会从默认的 10vp 放大为 12vp，从而达到文本与图标视觉上的协调性。

![Image 32: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/ab/v3/RVRMSiWxTpywupnEbEN36w/zh-cn_image_0000002097894880.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=29482898E6C02067D74E6E21314F3C808D3E512D7DDE112F1C18449D4223974C)

**手机设备 - 分栏布局跟随导航结构**

在业务的实际使用场景下会出现应用使用分栏布局进行适配，此时底部页签需要跟随应用导航结构明确展示层级，使用跟随应用的一级分栏，避免底部页签的展示始终凌驾于全量界面之上。

![Image 33: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/c4/v3/Y1NNMUigRIC6mY0KFP2iMA/zh-cn_image_0000001956811457.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=1F95D47384D58D82CAFB3880D672112D508F2CDBFCE163D67F44AC5010C58037)

**平板设备 - 横屏布局**

平板横屏情况下，底部页签可以通过 Tabs 组件的 [Vertical](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabs#vertical) 属性配置为竖状侧边导航，侧边导航固定在页面左侧。也可以通过动态配置规则，基于屏幕断点规则，当断点属于 840vp 以下时使用底部页签，在 840vp 以上时使用侧边页签。

![Image 34: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/aa/v3/zhfkaXk2QJ-5-cIezDHqNA/zh-cn_image_0000001929812014.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=C4909298524498DAEE48201D5A07C9EA7681939567A58D7B954D6C9378C27010)

**使用分割线区隔内容**

基于应用的场景和规则，如果需要明确区分页签与内容区的边界时，可以使用分割线来进行区分，通过 [divider](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-container-tabs#divider10) 接口进行配置。

![Image 35: 点击放大](https://contentcenter-vali-drcn.dbankcdn.cn/pvt_2/DeveloperAlliance_scene_100_1/19/v3/wao69hGDT6-B--tDmoY38Q/zh-cn_image_0000001929652630.png?HW-CC-KV=V1&HW-CC-Date=20261029T161315Z&HW-CC-Expire=86400&HW-CC-Sign=A1EDA5937CCDE131DA04BF485F0616DDB30DA1935B1F2379455C88FEC4481DC5)
