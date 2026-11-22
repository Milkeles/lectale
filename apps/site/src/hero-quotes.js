const pause = document.querySelector('.hero__pause');

pause.addEventListener('click', () => {
  const paused = pause.getAttribute('aria-pressed') === 'true';
  pause.setAttribute('aria-pressed', String(!paused));
});

// Let the orbit move only once its pause control works (A11Y-001).
pause.hidden = false;
