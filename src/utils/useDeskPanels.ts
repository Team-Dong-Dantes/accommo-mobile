import { computed, type Ref } from 'vue'
import { QTabPanels, QTabPanel } from 'quasar'
import { isDesktop } from '@/utils/useTabletMode'

/**
 * One set of tab markup, two layouts.
 *
 * On a phone or tablet a tabbed page is the swipeable QTabPanels it always was.
 * On desktop the same panels sit side by side in a card (.desk-card, app.scss),
 * so the panels become plain divs and every one of them renders. Written once
 * here rather than per page:
 *
 *   <component :is="panelsIs" v-bind="panelsProps">
 *     <component :is="panelIs" name="overview">…</component>
 *   </component>
 *
 * `panelsProps` carries QTabPanels' own props only when it is QTabPanels — a
 * div has no v-model, and `animated` / `swipeable` would land on it as stray
 * attributes.
 */
export function useDeskPanels<T extends string>(tab: Ref<T>) {
  const split = isDesktop
  const panelsIs = computed(() => (split.value ? 'div' : QTabPanels))
  const panelIs = computed(() => (split.value ? 'div' : QTabPanel))
  const panelsProps = computed(() =>
    split.value
      ? {}
      : {
          modelValue: tab.value,
          'onUpdate:modelValue': (v: T) => (tab.value = v),
          animated: true,
          swipeable: true,
        },
  )
  return { split, panelsIs, panelIs, panelsProps }
}
