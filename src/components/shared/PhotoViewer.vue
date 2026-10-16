<template>
  <!-- Full-screen photo viewer. Tapping the backdrop closes it, which is what
       a thumb reaches for first on a phone. Open while `modelValue` holds a URL. -->
  <q-dialog :model-value="!!modelValue" maximized @update:model-value="close">
    <div class="viewer" @click="close">
      <span v-if="caption" class="viewer-caption">{{ caption }}</span>
      <img :src="modelValue" alt="Photo" class="viewer-img" />
      <button type="button" class="viewer-close" aria-label="Close photo" @click.stop="close">
        <IconifyIcon icon="lucide:x" width="20" />
      </button>
      <!-- What the receipt in the photo should say, to check it against. -->
      <section v-if="compare" class="viewer-compare" aria-label="Compare with the receipt" @click.stop>
        <span class="viewer-kicker">Should match the receipt</span>
        <div class="viewer-ref">
          <span class="viewer-ref-text">
            <span class="viewer-key">Reference no.</span>
            <span class="viewer-refno">{{ compare.reference || 'None given' }}</span>
          </span>
          <button v-if="compare.reference" type="button" class="viewer-copy" aria-label="Copy reference number" @click="copy">
            <IconifyIcon :icon="copied ? 'lucide:check' : 'lucide:copy'" width="18" />
          </button>
        </div>
        <div class="viewer-facts">
          <span><span class="viewer-key">Amount</span><b>{{ compare.amount }}</b></span>
          <span><span class="viewer-key">Method</span><b>{{ compare.method }}</b></span>
          <span><span class="viewer-key">Sent</span><b>{{ compare.sent }}</b></span>
        </div>
      </section>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

// The viewer is always dark, so the compare panel uses fixed dark colours, not --m-* tokens.
const props = defineProps<{
  modelValue: string
  caption?: string
  compare?: { reference: string; amount: string; method: string; sent: string }
}>()
const emit = defineEmits<{ (e: 'update:modelValue', value: string): void }>()

function close() {
  emit('update:modelValue', '')
}

const copied = ref(false)
async function copy() {
  try {
    await navigator.clipboard.writeText(props.compare?.reference ?? '')
    copied.value = true
    setTimeout(() => (copied.value = false), 1500)
  } catch {
    // Clipboard blocked: the number is on screen to read out.
  }
}
</script>

<style scoped>
.viewer {
  position: relative;
  display: grid;
  width: 100%;
  height: 100%;
  place-items: center;
  padding: 16px;
  background: rgba(0, 0, 0, 0.92);
}
.viewer-img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}
.viewer-caption {
  position: absolute;
  top: calc(24px + env(safe-area-inset-top));
  left: 16px;
  right: 64px;
  color: rgba(255, 255, 255, 0.8);
  font-size: 13px;
  font-weight: 700;
}
.viewer-compare {
  position: absolute;
  left: 12px;
  right: 12px;
  bottom: calc(16px + env(safe-area-inset-bottom));
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  border: 1px solid #2a2e37;
  border-radius: 16px;
  background: #1a1d23;
  color: #f3f4f6;
}
.viewer-kicker,
.viewer-key {
  color: #94a3b8;
  font-size: 11.5px;
}
.viewer-kicker {
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.viewer-ref {
  display: flex;
  align-items: center;
  gap: 10px;
}
.viewer-ref-text,
.viewer-facts span {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.viewer-refno {
  font-family: var(--m-font-mono);
  font-size: 19px;
  font-weight: 600;
  letter-spacing: 0.06em;
  overflow-wrap: anywhere;
}
.viewer-copy {
  display: grid;
  flex: 0 0 44px;
  width: 44px;
  height: 44px;
  place-items: center;
  border: 1px solid #2a2e37;
  border-radius: 999px;
  background: transparent;
  color: inherit;
  cursor: pointer;
}
.viewer-facts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  padding-top: 10px;
  border-top: 1px solid #2a2e37;
  font-size: 14px;
}
.viewer-close {
  position: absolute;
  top: calc(12px + env(safe-area-inset-top));
  right: 12px;
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
</style>
