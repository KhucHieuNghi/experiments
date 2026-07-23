// Mobile sidebar toggle
document.addEventListener('DOMContentLoaded', () => {
  const btn = document.querySelector('.docs-menu-btn')
  const sidebar = document.querySelector('.docs-sidebar')
  if (btn && sidebar) {
    btn.addEventListener('click', () => {
      sidebar.classList.toggle('open')
    })
    document.addEventListener('click', (e) => {
      if (sidebar.classList.contains('open') && !sidebar.contains(e.target) && e.target !== btn) {
        sidebar.classList.remove('open')
      }
    })
  }

  // Mark active nav link
  const current = window.location.pathname.split('/').pop() || 'index.html'
  document.querySelectorAll('.docs-nav a').forEach(link => {
    const href = link.getAttribute('href')
    if (href === current || (current === 'index.html' && href === 'index.html')) {
      link.classList.add('active')
    }
  })
})
