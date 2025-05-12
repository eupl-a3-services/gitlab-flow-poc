#!/usr/bin/env node

console.info = (first, ...rest) => console.log('ℹ️', '\x1b[7m\x1b[34m INFO:\x1b[0m', '\x1b[34m' + first + '\x1b[0m', ...rest);
console.warn = (first, ...rest) => console.log('⚠️', '\x1b[7m\x1b[33m WARNING:\x1b[0m', '\x1b[33m' + first + '\x1b[0m', ...rest);
console.error = (first, ...rest) => console.log('❌', '\x1b[7m\x1b[31m ERROR:\x1b[0m', '\x1b[31m' + first + '\x1b[0m', ...rest);
console.success = (first, ...rest) => console.log('✅', '\x1b[7m\x1b[32m SUCCESS:\x1b[0m', '\x1b[32m' + first + '\x1b[0m', ...rest);

const path = require('path');
const fs = require('fs');

const envDir = process.argv[2] || '.';
const dotenvPath = path.resolve(envDir, '.env');

if (!fs.existsSync(dotenvPath)) {
  console.error(".env file not found at:", dotenvPath);
  process.exit(64);
}

require('dotenv').config({ path: dotenvPath });
console.info(`Loaded .env from:`, dotenvPath);

const axios = require('axios');
const yaml = require('js-yaml');
const CleanCSS = require('clean-css');
const sharp = require('sharp');

const categoryOrderYAML = `

`;
const timestamp = makeTimestamp();

const jiraConfig = loadYAMLData(`${envDir}/jira-report.yml`).jira;
const ALLOWED_COMPONENTS = Object.values(jiraConfig.components).flat();
console.info("ALLOWED_COMPONENTS:", ALLOWED_COMPONENTS);
const ALLOWED_STATUSES = Object.values(jiraConfig.statuses).flat();
console.info("ALLOWED_STATUSES:", ALLOWED_STATUSES);

const { JIRA_USER, JIRA_TOKEN, JIRA_URL, JIRA_KEY, DISCORD_WEBHOOK_URL } = process.env;
const TODAY = new Date();

const auth = {
  username: JIRA_USER,
  password: JIRA_TOKEN
};

const STATUSES_COMPLETED = jiraConfig.statuses.completed;
const STATUSES_WAITING   = jiraConfig.statuses.waiting;
const STATUSES_EXECUTING = jiraConfig.statuses.executing;
const STATUSES_BLOCKER   = jiraConfig.statuses.blocker;

function loadYAMLData(filePath) {
  try {
    // Čítanie súboru synchronne (pre jednoduchosť)
    const fileData = fs.readFileSync(filePath, 'utf8');
    
    // Načítanie YAML a vrátenie dát
    return yaml.load(fileData);
  } catch (error) {
    console.error("Chyba pri načítaní súboru alebo YAML:", error);
    return null;  // Vrátime null v prípade chyby
  }
}

function jiraIssueLink(key){
  return `${JIRA_URL}/browse/${key}`;
}

async function jiraUser() {
  const user = {};
  const jiraAPI = `${JIRA_URL}/rest/api/3/myself`;
  try {
    const response = await axios.get(jiraAPI, { auth });
    console.info("USER_NAME:", response.data.displayName)
    console.info("USER_EMAIL:", response.data.emailAddress)
    user.name = response.data.displayName;
    user.email = response.data.emailAddress;
  } catch (error) {
    console.error("Error while retrieving data from Jira:", error);
    process.exit(1);
  }
  return user;
}

async function lastEditedIssues() {
  const jiraAPI = `${JIRA_URL}/rest/api/3/search?jql=project=${JIRA_KEY} ORDER BY updated DESC&maxResults=10&fields=summary,updated,updatedBy`;
  try {
    const response = await axios.get(jiraAPI, { auth });
    const issues = response.data.issues.map(issue => {
      const updated = issue.fields.updated;
      return {
        key: issue.key,
        summary: truncate(issue.fields.summary, 80),
        updated: formatDateTime(updated),
        ago: timeDifference(updated),
        lastEditor: issue.fields.lastEditor?.displayName || 'Unknown'
      };
    });
    return issues;
  } catch (error) {
    console.error("Error while retrieving issues from Jira:", error);
    return [];
  }
}

async function processEditedIssues(edited) {
  console.table(edited);

  for (const edit of edited) {
    const editor = await issueWithLastEditor(edit.key);
    edit.lastEditor = editor.lastEditor;
  }

  console.table(edited);
}
async function issueWithLastEditor(issueKey) {
  console.info("Last Editor:", jiraIssueLink(issueKey));
  const url = `${JIRA_URL}/rest/api/3/issue/${issueKey}?expand=changelog`;
  try {
    const response = await axios.get(url, { auth });
    const fields = response.data.fields;
    const changelog = response.data.changelog;

    // Zober poslednú zmenu z changelogu
    const histories = changelog.histories;
    const lastChange = histories[histories.length - 1];
    const lastEditor = lastChange?.author?.displayName || 'Unknown';
    const updated = fields.updated;

    return {
//      key: response.data.key,
//      summary: fields.summary,
//      updated: formatDateTime(updated),
//      ago: timeDifference(updated),
        lastEditor: lastEditor
    };
  } catch (error) {
    console.error("Error loading issue:", issueKey, error);
    return null;
  }
}

async function jiraIssues() {
  const issues = [];
  let startAt = 0;
  const maxResults = 100;
  const fields = [
    'key',
    'summary',
    'status',
    'assignee',
    'duedate',
    'components',
    'updated'
  ].join(',');

  while (true) {  
    const jiraAPI = `${JIRA_URL}/rest/api/3/search?jql=project=${JIRA_KEY} ORDER BY key ASC&startAt=${startAt}&maxResults=${maxResults}&fields=${fields}`;
    try {
      const response = await axios.get(jiraAPI, { auth });
      console.info("Jira Issuess: ", "STATUS:", response.status, "START:", response.data.startAt, "RESULTS:", response.data.maxResults, "TOTAL:", response.data.total);
      issues.push(...response.data.issues);
      if (response.data.issues.length < maxResults) {
        break;
      }
  
      startAt += maxResults;
    } catch (error) {
      console.error("Error while retrieving data from Jira:", error);
      process.exit(2);
    }
  }
  return issues;
}

function makeTimestamp() {
    const now = new Date();
  
    const yy = String(now.getFullYear()).slice(-2);
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
  
    const hh = String(now.getHours()).padStart(2, '0');
    const min = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');
  
    return `${yy}${mm}${dd}-${hh}${min}${ss}`;
}
function formatDateTime(isoString) {
  const date = new Date(isoString);
  const pad = (n) => String(n).padStart(2, '0');
  const yy = String(date.getFullYear()).slice(2);
  const mm = pad(date.getMonth() + 1);
  const dd = pad(date.getDate());
  const hh = pad(date.getHours());
  const min = pad(date.getMinutes());
  const ss = pad(date.getSeconds());
  return `${yy}${mm}${dd}-${hh}${min}${ss}`;
}

function timeDifference(isoString) {
  const updatedTime = new Date(isoString);
  const now = new Date();
  const diffMs = now - updatedTime;

  const seconds = Math.floor(diffMs / 1000);
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  const pad = (n) => String(n).padStart(2, '0');
  return `${days} ${pad(hours)}:${pad(minutes)}:${pad(secs)}`;
}
function truncate(str, maxLength, suffix = '…') {
    if (str.length <= maxLength) return str;
    return str.slice(0, maxLength - suffix.length) + suffix;
}
function padRight(str, totalLength) {
  return str.toString().padEnd(totalLength, ' ');
}

function padLeft(str, totalLength) {
  return str.toString().padStart(totalLength, ' ');
}

function css(pie){
  const style = `
      body {
        background-color: #ccc;
        font-family: sans-serif;
      }
      #report{
        width: 1000px;
        margin: 0 auto;
        background: white;
        color: black;
        padding: 20px
      }
      h1 {
        border-bottom-style: hidden;
        text-align: center;
      }
      #pie {
        width: 100%;
        height: 200px;
        background-image: url("${pie}");
        background-repeat: no-repeat;
        background-position: center;
      }
      h2 {
        border-color: black !important;
        border-bottom-width: 1px;
        border-bottom-style: solid;
        padding-bottom: 0.3em;
      }
      h3 {
        margin-left: 10px;
      }
      pre {
        margin-left: 40px;
        background-color: #222;
        color: #ccc ! important;
      }
      a {
        font-weight: bold;
        color: black
      }
      a:hover {
        font-weight: bold;
        color: black
      }
      table { 
        width: 960px;
        margin-left: 40px;
        border-color: black !important;
      }
      table > thead > tr > th {
        border-bottom: 1px solid !important;
      }
      th:nth-child(1), td:nth-child(1) { width: 100px; padding-left: 0px;}
      td:nth-child(1) { padding-left: 25px; }
      th:nth-child(2), td:nth-child(2) { width: 130px; }
      th:nth-child(3), td:nth-child(3) { width: 65px; }
      th:nth-child(4), td:nth-child(4) { width: 75px; }
  `;
  return `<style>${new CleanCSS().minify(style).styles}</style>`;
}
function dateColor(duedate) {
  if (duedate == '-') {
    return "#000000";
  } else {
    let dueDateObj = new Date(duedate);
    let diffTime = dueDateObj - TODAY;
    let diffDays = diffTime / (1000 * 3600 * 24);

    if (diffDays > 7) {
      return "#359b64";
    } else if (diffDays > 0) {
      return "#f39c12";
    } else {
      return "#c0392b";
    }
  }
}
function formatIssueLine(issue) {
    const status = issue.fields.status.name.padEnd(15);
    const assigneeValue = issue.fields.assignee?.displayName ?? 'Unassigned';
    const assignee = assigneeValue.padEnd(20);
    let key = issue.key;
    key = `[${key}](${jiraIssueLink(key)})`.padEnd(55)
    let duedate = issue.fields.duedate ?? '-';
    let duedatecolor = dateColor(duedate);
    duedate = `<b style="color:${duedatecolor};">${duedate}</b>`.padEnd(10);
    const summary = truncate(issue.fields.summary, 65).padEnd(90);
    return `${status} | ${assignee} | ${key} | ${duedate} | ${summary}`;
  }
  
  function summaryIssues(issues) {
    const componentSummary = {};
    const totalSummary = {
      total: 0,
      completed: 0,
      blocker: 0,
      waiting: 0,
      executing: 0
    };
  
    //console.log(jiraConfig.components);    
    issues.forEach(issue => {
      const components = issue.fields.components.map(comp => comp.name);
      const status = issue.fields.status.name;
  
      if (components.length < 1) {
        console.warn('Issue has no component:', components.length, jiraIssueLink(issue.key));
      }
      if (components.length > 1) {
        console.warn('Issue has too many components:', components.length, jiraIssueLink(issue.key));
      }
      if (components.length >= 1 && !ALLOWED_COMPONENTS.includes(components[0])) {
        console.warn('Component is not allowed:', `'${components[0]}'`, jiraIssueLink(issue.key));
      }
      if (!ALLOWED_STATUSES.includes(status)) {
        console.warn('Status is not allowed:', `'${status}'`, jiraIssueLink(issue.key));
      }
      components.forEach(component => {
        if (!componentSummary[component]) {
          componentSummary[component] = {
            total: 0,
            completed: 0,
            blocker: [],
            waiting: [],
            executing: []
          };
        }
        componentSummary[component].total++;
        const formattedLine = formatIssueLine(issue);
        totalSummary.total++;
        if (STATUSES_COMPLETED.includes(status)) {
          componentSummary[component].completed++;
          totalSummary.completed++;
        } else {
          if (STATUSES_BLOCKER.includes(status)) {
            componentSummary[component].blocker.push(formattedLine);
            totalSummary.blocker++;
          } else if (STATUSES_WAITING.includes(status)) {
            componentSummary[component].waiting.push(formattedLine);
            totalSummary.waiting++;
          } else if (STATUSES_EXECUTING.includes(status)) {
            componentSummary[component].executing.push(formattedLine);
            totalSummary.executing++;
          }
        }
      });
    });
    return {
      totalSummary,
      componentSummary
    };
  }
  

function progressBar(percent, emoji = '🟩', length = 10) {
    const filledCount = Math.round((percent / 100) * length);
    const emptyCount = length - filledCount;

    const filled = emoji.repeat(filledCount);
    const empty = '⬜'.repeat(emptyCount);

    return `${filled}${empty} ${padLeft(percent.toFixed(1),6)}%`;
}

function componentLink(component){
  const base = `${JIRA_URL}/issues/`;
  const jql = `project = ${JIRA_KEY} AND component = "${component}"`;
  const encodedURL = `${base}?jql=${encodeURIComponent(jql)}`;
  return `[${component}](${encodedURL})`;
}

async function convertSvgToBase64Png(svgString) {
  try {
    // Čakáme na výsledok asynchrónnej operácie
    const pngBuffer = await sharp(Buffer.from(svgString))
      .png()
      .toBuffer(); // Čakáme na buffer ako Promise

    // Konverzia bufferu na base64
    const base64Png = pngBuffer.toString('base64');
    console.log('data:image/png;base64,' + base64Png);
  } catch (err) {
    console.logError('Chyba pri konverzii:', err);
  }
}

async function convertSvgToBase64WebP(svgString) {
  try {
    // Konverzia SVG na WebP a získanie bufferu (synchronná verzia)
    const webpBuffer = await sharp(Buffer.from(svgString))
      .webp()
      .toBuffer(); // Používame synchronnú metódu toBufferSync

    // Konverzia bufferu na base64
    const base64WebP = webpBuffer.toString('base64');

    // Vytvorenie base64 reťazca vo formáte "data:image/webp;base64,..."
    console.log("webP", base64WebP);
    return `data:image/webp;base64,${base64WebP}`;
  } catch (err) {
    console.error("Chyba pri konverzii:", err);
    return null;
  }
}
function consoleLegend(totalSummary){
  const emojiMap = {
    blocker: '🟠 Blocker',
    waiting: '🟡 Waiting',
    executing: '🔵 Executing',
    completed: '🟢 Completed',
    total: '📊 Total'
  };
  const totalSummaryOrder = ['blocker', 'waiting', 'executing', 'completed', 'total'];
  const totalSummarySorted = totalSummaryOrder.map(key => ({ Status: emojiMap[key] || key, Value: totalSummary[key] }));
  console.table(totalSummarySorted);

}

function pieSvg(summary) {
  const {totalSummary, componentSummary} = summary;
  const data = [
    { label: "🟠 Blocker",   value: totalSummary.blocker,   color: '#ff6723' },
    { label: "🟡 Waiting",   value: totalSummary.waiting,   color: '#fcd53f' },
    { label: "🔵 Executing", value: totalSummary.executing, color: '#0074ba' },
    { label: "🟢 Completed", value: totalSummary.completed, color: '#00d26a' },
  ];
  
  consoleLegend(totalSummary);

  const svg = generatePieSVG(data);

  //const base64WebP = convertSvgToBase64WebP(svg);
  //console.log("wwww ......................... ", base64WebP);

  const base64 = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
  //const svgBase64 = `<img src="data:image/svg+xml;base64,${base64}" width="400" height="200" alt="SVG Image">`;

  return base64;
}

function generatePieSVG(data) {
  const total = data.reduce((sum, d) => sum + d.value, 0);
  let angle = -90;
  const cx = 100, cy = 100, r = 100;

  const parts = data.map(d => {
    const start = angle;
    const slice = (d.value / total) * 360;
    angle += slice;
    const x1 = cx + r * Math.cos(Math.PI * start / 180);
    const y1 = cy + r * Math.sin(Math.PI * start / 180);
    const x2 = cx + r * Math.cos(Math.PI * angle / 180);
    const y2 = cy + r * Math.sin(Math.PI * angle / 180);
    const largeArc = slice > 180 ? 1 : 0;
    return `<path d="M${cx},${cy} L${x1},${y1} A${r},${r} 0 ${largeArc},1 ${x2},${y2} Z" fill="${d.color}"/>`;
  });
  const legend = data.map((d, i) => {
    const y = 40 + i * 30;
    return `<text y="${y}" font-size="14" alignment-baseline="middle"><tspan x="250">${d.label}:</tspan><tspan x="370" text-anchor="end">${d.value}</tspan></text>`;
  });
  const totalY = 40 + data.length * 30;
  const lineY = totalY - 20;
  legend.push(`<line x1="240" x2="380" y1="${lineY}" y2="${lineY}" stroke="#000" stroke-width="1"/>`);
  legend.push(`<text y="${totalY}" font-size="14" alignment-baseline="middle"><tspan x="250">📊 Total:</tspan><tspan x="370" text-anchor="end">${total}</tspan></text>`);
  return `<svg width="400" height="200" viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg" style="font-family: sans-serif">${parts.join('')}${legend.join('')}</svg>`;
}



function reportBuilder(summary, pie) {
  const {totalSummary, componentSummary} = summary;
  let message = ``;
  message += `<div id="report">\n\n`;
  message += `# Project Delivery Report: ${JIRA_KEY} | ⏱️ ${timestamp}\n\n`;
  //message += `${pie}`;
  //message += `<img src="${pie}" width="400" height="200" alt="SVG Image">`;
  message += `<div id="pie"></div>`;
  message += `\n\n`;

  let blockers = false;
  let categoryId = 0;

  Object.entries(jiraConfig.components).forEach(([groupName, components]) => {
    categoryId++;
    message += `## ${categoryId}. ${groupName}\n`;
    let componentId = 0;
    
    components.forEach(component => {
        const stats = componentSummary[component];
        if (!stats) {
            return;
        }
        const progress = (stats.completed / stats.total) * 100;
        const isBlocked = stats.blocker.length > 0;

        let status = '';
        if (!isBlocked) {
            status += `🟩`;
        } else {
            status += `🟧`;
        }

        componentId++;
        message += `### ${status} ${categoryId}.${componentId} ${componentLink(component)}\n`;
        message += "```\n";
        message += `${padLeft(stats.completed, 3)} / ${padRight(stats.total, 3)} ${progressBar(progress, status, 40)}\n`;
        message += "```\n";
        
        if (stats.waiting.length > 0) {
            message += `|🟡 Waiting (${stats.waiting.length})|||||\n`;
            message += `|-|-|-|-|-|\n`;
            stats.waiting.forEach(waitingItem => {
                message += `|${waitingItem}|\n`;
            });
            message += `\n`;
        }

        if (stats.executing.length > 0) {
            message += `|🔵 Executing (${stats.executing.length})|||||\n`;
            message += `|-|-|-|-|-|\n`;
            stats.executing.forEach(executingItem => {
                message += `|${executingItem}|\n`;
            });
            message += `\n`;
        }

        if (stats.blocker.length > 0) {
            message += `|🟠 Blocker (${stats.blocker.length})|||||\n`;
            message += `|-|-|-|-|-|\n`;
            stats.blocker.forEach(blockerItem => {
                message += `|${blockerItem}|\n`;
            });
            message += `\n`;
        }
        message += `\n`;
    });
  });
  message += `</div>`;
  message += css(pie);
  return message;
}

async function sendToDiscord(message) {
  try {
    await axios.post(DISCORD_WEBHOOK_URL, { content: message });
    console.log('Správa bola úspešne odoslaná na Discord!');
  } catch (error) {
    console.error('Chyba pri odosielaní správy na Discord:', error);
  }
}

async function main() {
  const userObject = await jiraUser();
  
  const edited = await lastEditedIssues();
  await processEditedIssues(edited);

  const issues = await jiraIssues();
  const summary = summaryIssues(issues);

  const svg = await pieSvg(summary);
  const report = reportBuilder(summary, svg);
  // console.log(report);
  fs.mkdirSync('report', { recursive: true });
  const fileName = `report/pdr-${JIRA_KEY.toLowerCase()}.md`;
  const fileNameTs = `report/pdr-${JIRA_KEY.toLowerCase()}-${timestamp}.md`;
  fs.writeFileSync(fileName, report, 'utf8');
  fs.writeFileSync(fileNameTs, report, 'utf8');
  console.success("Report has been saved to:", fileName);
  console.success("Another copy was saved as:",fileNameTs);

 //await sendToDiscord(message);
}

main();
