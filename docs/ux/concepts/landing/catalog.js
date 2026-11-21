// Filters the catalog cards in place. Without this script the form still
// works as a plain GET and every card stays visible. Same-origin, no network.
(() => {
  const form = document.querySelector('[data-filter-form]');
  if (!form) return;
  const cards = [...document.querySelectorAll('[data-course]')];
  const count = document.querySelector('[data-count]');
  const empty = document.querySelector('[data-empty]');
  const emptyTitle = document.querySelector('[data-empty-title]');
  const list = document.querySelector('[data-cards]');
  const { q, lang, subject } = form.elements;
  const note = ' These are examples. They are not real courses.';

  const params = new URLSearchParams(location.search);
  q.value = params.get('q') || '';

  function apply() {
    const term = q.value.trim().toLowerCase();
    let shown = 0;
    for (const card of cards) {
      const hit =
        (!term || card.dataset.text.includes(term)) &&
        (!lang.value || card.dataset.lang === lang.value) &&
        (!subject.value || card.dataset.subject === subject.value);
      card.hidden = !hit;
      if (hit) shown += 1;
    }
    list.hidden = shown === 0;
    empty.hidden = shown !== 0;
    count.hidden = shown === 0;
    count.textContent = `${shown} example ${shown === 1 ? 'course' : 'courses'}.${note}`;
    emptyTitle.textContent = term ? `No courses match “${q.value.trim()}”` : 'No courses match these filters';
  }

  form.addEventListener('input', apply);
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    apply();
  });
  document.querySelector('[data-clear]').addEventListener('click', () => {
    q.value = '';
    lang.value = '';
    subject.value = '';
    apply();
    q.focus();
  });
  apply();
})();
