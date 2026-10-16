import { Capacitor, registerPlugin } from '@capacitor/core'
import { Filesystem, Directory, Encoding } from '@capacitor/filesystem'
import { Share } from '@capacitor/share'
import { Notify } from 'quasar'

// Printing and sharing for generated HTML documents (the rent report, receipts).
// Native: PrintPlugin.java (Android PrintManager, whose dialog includes "Save as
// PDF"). Web: a hidden iframe. There is no JS PDF library: PDF is Print → Save as PDF.

interface PrintPlugin {
  print(opts: { html: string; name: string; paper: string; orientation: string }): Promise<void>
}
const Print = registerPlugin<PrintPlugin>('Print')

export interface PrintOptions {
  name: string
  paper?: 'a4' | 'long'
  orientation?: 'portrait' | 'landscape'
}

export async function printHtml(html: string, { name, paper = 'a4', orientation = 'portrait' }: PrintOptions): Promise<void> {
  if (Capacitor.isNativePlatform()) {
    // An APK from before the plugin existed has no Print; the web bundle can arrive first (live update).
    if (!Capacitor.isPluginAvailable('Print')) {
      Notify.create({ message: 'Update the app to print.', color: 'grey-9', textColor: 'white', position: 'top', classes: 'custom-notify' })
      return
    }
    await Print.print({ html, name, paper, orientation })
    return
  }
  const frame = document.createElement('iframe')
  frame.style.cssText = 'position:fixed;width:0;height:0;border:0;visibility:hidden'
  frame.srcdoc = html
  frame.onload = () => {
    frame.contentWindow?.focus()
    frame.contentWindow?.print()
    // Removing it at once would close the dialog on some browsers.
    setTimeout(() => frame.remove(), 60_000)
  }
  document.body.appendChild(frame)
}

/** Shares the document as `<name>.html`: the share sheet on a device, else a download. */
export async function shareHtml(html: string, { name, title }: { name: string; title: string }): Promise<void> {
  const file = `${name}.html`
  if (Capacitor.isNativePlatform()) {
    const { uri } = await Filesystem.writeFile({ path: file, data: html, directory: Directory.Cache, encoding: Encoding.UTF8 })
    await Share.share({ title, files: [uri] })
    return
  }
  const blob = new File([html], file, { type: 'text/html' })
  if (navigator.canShare?.({ files: [blob] })) {
    await navigator.share({ title, files: [blob] })
    return
  }
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = file
  a.click()
  URL.revokeObjectURL(a.href)
}
