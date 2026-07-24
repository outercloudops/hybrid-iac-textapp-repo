/**
 * THE FOUNDING MIRROR — main.js
 * 1607 — 1797
 *
 * Controls the full-viewport overlay experience.
 *
 * Flow:
 *   Landing page → user clicks "Begin the Experience"
 *   → overlay covers the full window
 *   → Alien title materialization + intro text animate in
 *   → first question appears automatically
 *   → 10 questions / responses / outro
 *   → overlay stays on screen (no close button)
 *   → browser back or refresh to leave
 *
 * API: one fetch() to /api/ask per user answer.
 * CloudFront routes /api/* → API Gateway → Lambda → Anthropic.
 */

"use strict";

// ── Questions ─────────────────────────────────────────────────────────────────

const QUESTIONS = [
  {
    id: 1,
    weight: "opening",
    text: "When the colonists broke from Britain in 1776, what do you believe they were truly trying to escape?"
  },
  {
    id: 2,
    weight: "light",
    text: "Do you believe a person has the right to live however they choose — as long as they aren't harming anyone else?"
  },
  {
    id: 3,
    weight: "light-moderate",
    text: "Should the government have the authority to decide what a citizen may or may not put into their own body?"
  },
  {
    id: 4,
    weight: "moderate",
    text: "Who should hold more power over your daily life — your state government, or the federal government in Washington?"
  },
  {
    id: 5,
    weight: "moderate",
    text: "Is it just for a government to collect taxes from people who had no meaningful vote or voice in how that money is spent?"
  },
  {
    id: 6,
    weight: "moderate-heavy",
    text: "Should a person be legally punished for saying something — even something most people find dangerous, offensive, or wrong?"
  },
  {
    id: 7,
    weight: "heavy",
    text: "Do you believe every person in America — regardless of origin, religion, or how they live — deserves the exact same protection under the law?"
  },
  {
    id: 8,
    weight: "heavy",
    text: "Is it ever acceptable for a government to force its citizens to fight in a war they personally oppose and never voted for?"
  },
  {
    id: 9,
    weight: "very-heavy",
    text: "If a majority votes for a law that strips a minority of their natural rights — is it still a just law?"
  },
  {
    id: 10,
    weight: "confrontation",
    text: "Looking at everything you've said tonight — do you believe the America that exists right now is the one the founders intended to build? And where do you truly stand within it?"
  }
];

// ── Config ────────────────────────────────────────────────────────────────────

const API_ENDPOINT        = "/api/ask";
const DELAY_TITLE_LETTER  = 90;           // ms per letter in materialization
const DELAY_TITLE_ANIM    = 1400;         // ms for each letter's animation
const DELAY_QUESTION_CHAR = 28;           // ms per char in question typewriter
const DELAY_RESPONSE_CHAR = 18;           // ms per char in response typewriter
const DELAY_INTRO_LINE    = 3000;          // ms between intro lines
const IDLE_TIMEOUT_MS     = 4 * 60 * 1000;  // 4 minutes idle warning

// ── State ─────────────────────────────────────────────────────────────────────

let currentIndex  = 0;
let idleTimer     = null;
let lastSubmitted = null;  // stored for retry
let aborted = false;
let experienceRunning = false; 
let sessionId = 0;

// ── DOM References ────────────────────────────────────────────────────────────

const appOverlay      = document.getElementById("app-overlay");
const landingBeginBtn = document.getElementById("landing-begin-btn");

const titleScreen    = document.getElementById("title-screen");
const questionScreen = document.getElementById("question-screen");
const responseScreen = document.getElementById("response-screen");
const outroScreen    = document.getElementById("outro-screen");
const loadingEl      = document.getElementById("loading");
const errorDisplay   = document.getElementById("error-display");

const titleText      = document.getElementById("title-text");
const introLines     = [
  document.getElementById("line-1"),
  document.getElementById("line-2"),
  document.getElementById("line-3"),
  document.getElementById("line-4"),
  document.getElementById("line-5")
];

const questionCounter = document.getElementById("question-counter");
const questionText    = document.getElementById("question-text");
const answerInput     = document.getElementById("answer-input");
const submitBtn       = document.getElementById("submit-btn");
const idleWarning     = document.getElementById("idle-warning");

const responseText   = document.getElementById("response-text");
const continueBtn    = document.getElementById("continue-btn");
const closeBtn       = document.getElementById("close-btn");
const overlayCloseBtn = document.getElementById("overlay-close-btn");

const outroText      = document.getElementById("outro-text");

const errorMessage   = document.getElementById("error-message");
const retryBtn       = document.getElementById("retry-btn");


// ── Utilities ─────────────────────────────────────────────────────────────────

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function showEl(el)  { el.classList.remove("hidden"); }
function hideEl(el)  { el.classList.add("hidden"); }

function showScreen(screen) {
  [titleScreen, questionScreen, responseScreen, outroScreen].forEach(s => {
    s.classList.add("hidden");
  });
  screen.classList.remove("hidden");
}

function showError(msg) {
  errorMessage.textContent = msg;
  showEl(errorDisplay);
  hideEl(loadingEl);
}

function clearError() {
  hideEl(errorDisplay);
}


// ── Color Phase ───────────────────────────────────────────────────────────────
// Changes text color as questions get heavier.
// Applied to the overlay element so only the overlay changes, not the landing page.

function setColorPhase(questionId) {
  appOverlay.classList.remove("phase-white", "phase-blue", "phase-red");
  if (questionId <= 3)       appOverlay.classList.add("phase-white");
  else if (questionId <= 6)  appOverlay.classList.add("phase-blue");
  else                       appOverlay.classList.add("phase-red");
}


// ── Idle Timer ────────────────────────────────────────────────────────────────

function startIdleTimer() {
  clearIdleTimer();
  idleTimer = setTimeout(() => showEl(idleWarning), IDLE_TIMEOUT_MS);
}

function resetIdleTimer() {
  hideEl(idleWarning);
  startIdleTimer();
}

function clearIdleTimer() {
  if (idleTimer) {
    clearTimeout(idleTimer);
    idleTimer = null;
  }
}


// ── Alien 1979 Title Materialization ─────────────────────────────────────────
// Letters materialize one at a time with a staggered delay.
// The @keyframes materialize animation is defined in style.css.

function materializeTitle(text) {
  titleText.innerHTML = "";

  text.split("").forEach((char, i) => {
    const span = document.createElement("span");
    span.textContent = (char === " ") ? "\u00A0" : char;  // preserve spaces
    const delaySec = (i * DELAY_TITLE_LETTER / 1000).toFixed(2);
    span.style.animation = `materialize 1.4s ease-out ${delaySec}s forwards`;
    titleText.appendChild(span);
  });

  // Wait for all letters to finish materializing
  const totalMs = (text.length * DELAY_TITLE_LETTER) + DELAY_TITLE_ANIM;
  return sleep(totalMs);
}


// ── Intro Sequence ────────────────────────────────────────────────────────────

const INTRO_LINES_TEXT = [
  "Ten questions.",
  "No wrong answers.",
  "Only what you actually believe.",
  "Answer honestly. The mirror does not grade.",
  "It only reflects."
];

async function runIntroSequence(mySession) {
  // Reset all lines — force reflow to clear any lingering transition state
  introLines.forEach(line => {
    line.style.transition = "none";
    line.textContent = "";
    line.classList.remove("visible");
    line.offsetHeight; // forces the browser to reflow before restoring transition
    line.style.transition = "";
  });

  
  await new Promise(resolve => requestAnimationFrame(resolve));

  for (let i = 0; i < introLines.length; i++) {
    if (aborted || sessionId != mySession) return;
    introLines[i].textContent = INTRO_LINES_TEXT[i];
    introLines[i].classList.add("visible");
    await sleep(DELAY_INTRO_LINE);
  }
}


// ── API Call ──────────────────────────────────────────────────────────────────

async function callAPI(question, userAnswer) {
  const res = await fetch(API_ENDPOINT, {
    method:  "POST",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify({
      question_id:     question.id,
      question_weight: question.weight,
      question_text:   question.text,
      user_answer:     userAnswer
    })
  });

  const data = await res.json();

  if (!res.ok) {
    throw new Error(data.error || `Request failed (${res.status})`);
  }

  return data.response;
}


// ── Typewriter ────────────────────────────────────────────────────────────────

async function typewrite(element, text, delay, mySession) {
  element.textContent = "";
  for (const char of text) {
    if (aborted || (mySession !== undefined && sessionId !== mySession)) return;
    element.textContent += char;
    await sleep(delay);
  }
}


// ── Outro ─────────────────────────────────────────────────────────────────────

const OUTRO_LINES = [
  "You have reached the end.",
  "",
  "The mirror remains.",
  "",
  "What you were told this country is,",
  "and what it was built to be,",
  "are not always the same thing.",
  "",
  "The distance between those two things",
  "is where you live."
];

async function runOutro() {
  showScreen(outroScreen);
  outroText.textContent = "";

  for (const line of OUTRO_LINES) {
    if (aborted || sessionId !== mySession) return;
    if (line === "") {
      outroText.textContent += "\n";
    } else {
      for (const char of line) {
        if (aborted || sessionId !== mySession) return;
        outroText.textContent += char;
        await sleep(22);
      }
      outroText.textContent += "\n";
    }
    await sleep(600);
  }
}


// ── Experience Flow ───────────────────────────────────────────────────────────

async function startExperience() {
  if (experienceRunning) return;
  experienceRunning = true;
  aborted = false;
  sessionId++;         // invalidates all previous async calls
  const mySession = sessionId;

  // Show overlay — covers the full window
  appOverlay.classList.remove("hidden");
  appOverlay.classList.add("phase-white");

  // Title screen is visible by default inside the overlay
  await sleep(300);
  
  if (aborted) return;

  await materializeTitle("THE FOUNDING MIRROR");
  
  if (aborted) return;

  await sleep(700);

  if (aborted) return;

  await runIntroSequence();

  if (aborted) return;

  await sleep(3000);

  if (aborted) return;

  await showQuestion(QUESTIONS[currentIndex], mySession);
}

async function showQuestion(question, mySession) {
  clearError();
  hideEl(loadingEl);
  setColorPhase(question.id);
  showScreen(questionScreen);

  hideEl(idleWarning);
  hideEl(submitBtn);
  answerInput.value = "";
  questionText.textContent = "";
  questionCounter.textContent = `[ ${question.id} / 10 ]`;

  await typewrite(questionText, question.text, DELAY_QUESTION_CHAR, mySession);
  if (aborted || sessionId !== mySession) return;

  if (aborted) return;

  await sleep(300);

  if (aborted || sessionId !== mySession) return;

  showEl(submitBtn);
  answerInput.focus();
  startIdleTimer();
}

async function handleSubmit() {
  const answer = answerInput.value.trim();
  if (!answer) {
    answerInput.focus();
    return;
  }

  const mySession = sessionId;

  clearIdleTimer();
  hideEl(idleWarning);
  hideEl(submitBtn);
  clearError();
  showEl(loadingEl);

  const question = QUESTIONS[currentIndex];
  lastSubmitted  = { question, answer };

  let aiResponse;
  try {
    aiResponse = await callAPI(question, answer);
  } catch (err) {
    if (aborted || sessionId !== mySession) return;
    hideEl(loadingEl);
    showError(err.message || "Something went wrong. Please try again.");
    showEl(submitBtn);
    return;
  }

  if (aborted || sessionId !== mySession) return;

  hideEl(loadingEl);
  showScreen(responseScreen);
  hideEl(continueBtn);
  responseText.textContent = "";

  await typewrite(responseText, aiResponse, DELAY_RESPONSE_CHAR, mySession);

  if (aborted || sessionId !== mySession) return;

  await sleep(400);

  if (aborted || sessionId !== mySession) return;

  showEl(continueBtn);
}

async function handleContinue() {
  if (aborted) return;
  const mySession = sessionId;
  hideEl(continueBtn);
  currentIndex++;
  if (currentIndex >= QUESTIONS.length) {
    await runOutro(mySession);
    if (sessionId === mySession) experienceRunning = false;
  } else {
    await showQuestion(QUESTIONS[currentIndex], mySession);
  }
}

async function handleRetry() {
  if (!lastSubmitted) return;

  const mySession = sessionId;

  clearError();
  showEl(loadingEl);
  hideEl(retryBtn);

  let aiResponse;
  try {
    aiResponse = await callAPI(lastSubmitted.question, lastSubmitted.answer);
  } catch (err) {
    if (aborted || sessionId !== mySession) return;
    hideEl(loadingEl);
    showError(err.message || "Still unable to reach the mirror. Try again.");
    showEl(retryBtn);
    return;
  }

  if (aborted || sessionId !== mySession) return;

  hideEl(loadingEl);
  hideEl(errorDisplay);
  showScreen(responseScreen);
  hideEl(continueBtn);
  responseText.textContent = "";

  await typewrite(responseText, aiResponse, DELAY_RESPONSE_CHAR, mySession);

  if (aborted || sessionId !== mySession) return;

  await sleep(400);

  if (aborted || sessionId !== mySession) return;

  showEl(continueBtn);
}

function closeExperience() {
  experienceRunning = false;
  aborted = true;
  hideEl(appOverlay);
  hideEl(loadingEl);
  hideEl(errorDisplay);
  currentIndex  = 0;
  lastSubmitted = null;
  clearIdleTimer();
  introLines.forEach(line => {
    line.textContent = "";
    line.classList.remove("visible");
  });
  titleText.innerHTML = "";
  appOverlay.classList.remove("phase-white", "phase-blue", "phase-red");
  showScreen(titleScreen);
}

// ── Event Listeners ───────────────────────────────────────────────────────────

// Landing page Begin button — triggers the overlay and starts the experience
landingBeginBtn.addEventListener("click", startExperience);

submitBtn.addEventListener("click", handleSubmit);

// Ctrl+Enter or Cmd+Enter submits the answer
answerInput.addEventListener("keydown", (e) => {
  resetIdleTimer();
  if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    handleSubmit();
  }
});

continueBtn.addEventListener("click", handleContinue);
closeBtn.addEventListener("click", closeExperience);
retryBtn.addEventListener("click", handleRetry);
overlayCloseBtn.addEventListener("click", closeExperience);
