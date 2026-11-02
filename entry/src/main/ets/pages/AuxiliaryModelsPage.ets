import { AuxiliaryModelSettings } from '../components/AuxiliaryModelSettings';
import { PageSurface } from '../components/PageSurface';
import { PageHeader } from '../components/PageHeader';
import { ROOT_PATH_STACK } from '../nav/RootNav';

@Component
export struct AuxiliaryModelsPage {
  @Builder
  header() {
    PageHeader({ title: '辅助模型设置', subtitle: '为配置、对话草稿与状态栏选择模型',
      onBack: (): void => { ROOT_PATH_STACK.pop(); } })
  }
  @Builder
  content() { AuxiliaryModelSettings() }
  build() {
    PageSurface({ topBar: (): void => { this.header(); }, content: (): void => { this.content(); } })
  }
}
