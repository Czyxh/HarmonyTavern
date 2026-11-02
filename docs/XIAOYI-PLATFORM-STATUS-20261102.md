# 小艺平台注册现状与调用方向核查（2026-11-02）

只读查看用户已创建项目，未更改编排、白名单、隐私协议、内容合规或上架状态。

## 已确认的平台信息

- 名称：酒馆连接助手
- 平台Agent ID：agent4e516f48b125443cb4da83b0a10c5cef
- 应用内Agent ID：harmonytavern.connection-assistant
- Bundle：com.example.harmonytavern
- 应用服务名称：HarmonyTavernAgentExtensionAbility
- 开发模式：端A2A（原生）
- 状态：草稿；页面显示“上架（2项未完成）”。尚不能据此认定已发布或可真机调用。
- 平台正确导入了配置草稿识别技能及输入/输出媒体类型。

## 必须保留的范围边界

用户原始需求是应用内置可用的小模型或让小艺提供AI配置能力。当前完成的是应用Agent注册和端A2A服务；执行逻辑仍是本机规则解析器。现有“AI整理”仍调用用户已经配置的模型服务商。不能把注册成功、A2A代码可编译或拉起FunctionComponent等同于小艺模型替代现有后端。

官方快速开始的能力对照表明确：端A2A模式“模型”为否，单Agent/多Agents模式“模型”为是。端A2A用于应用Agent与小艺Client Agent通信。单Agent模式可以按需选择模型，但目前尚未验证应用获取结构化生成结果并回填服务商草稿的正式通道。

来源：https://developer.huawei.com/consumer/cn/doc/doccenter-celia/quickstart-0000002762985731
官方SDK：@kit.AgentFrameworkKit当前导出FunctionComponent/AgentController及A2A Server接口，没有在该Kit的现有接口中发现供应用直接调用并返回任意文本的通用生成客户端。

## 后续

- 现有端A2A项目保留，不覆盖为其他模式，不自动提交上架或接受平台协议。
- 若继续小艺模型方案，应先验证带模型单Agent的应用调用/结果回填官方路径，再实现；没有结果回填证据时不能仅增加“打开小艺”入口作为完成。
- 或在原授权范围内落地真实离线生成模型与推理运行时，不能把规则解析器标为本地模型。
- 未更换工程内agentId为平台ID；两者是平台页面明确区分的字段。
