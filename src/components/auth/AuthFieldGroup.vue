<template>
  <!-- One border round the whole set, hairlines between rows. The surface is
       defined once in app.scss as `.auth-group`, alongside the `.auth-field`
       rows it contains. -->
  <div class="auth-group">
    <slot />
  </div>
</template>
