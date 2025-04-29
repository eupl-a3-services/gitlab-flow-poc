#!/usr/bin/env node

require('dotenv').config();
const axios = require('axios');
const yaml = require('js-yaml');
const path = require("path");
const fs = require('fs');
const CleanCSS = require('clean-css');

const categoryOrderYAML = `

`;
const timestamp = makeTimestamp();

const jiraReportYml = process.env.WORKSPACE
  ? path.join(process.env.WORKSPACE, "jira-report.yml")
  : "jira-report.yml";

const jiraConfig = loadYAMLData(jiraReportYml).jira;

const { JIRA_USER, JIRA_TOKEN, JIRA_URL, PROJECT_KEY, DISCORD_WEBHOOK_URL } = process.env;

const auth = {
  username: JIRA_USER,
  password: JIRA_TOKEN
};

const STATUSES_COMPLETED = jiraConfig.status.completed;
const STATUSES_WAITING   = jiraConfig.status.waiting;
const STATUSES_EXECUTING = jiraConfig.status.executing;
const STATUSES_BLOCKER   = jiraConfig.status.blocker;

function loadYAMLData(filePath) {
  try {
    // Čítanie súboru synchronne (pre jednoduchosť)
    const fileData = fs.readFileSync(filePath, 'utf8');
    
    // Načítanie YAML a vrátenie dát
    return yaml.load(fileData);
  } catch (error) {
    console.error(`Chyba pri načítaní súboru alebo YAML: ${error}`);
    return null;  // Vrátime null v prípade chyby
  }
}
async function getJiraIssues() {
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
    const jiraAPI = `${JIRA_URL}/rest/api/3/search?jql=project=${PROJECT_KEY} ORDER BY key ASC&startAt=${startAt}&maxResults=${maxResults}&fields=${fields}`;
    try {
      const response = await axios.get(jiraAPI, { auth });
      issues.push(...response.data.issues);
      if (response.data.issues.length < maxResults) {
        break;
      }
  
      startAt += maxResults;
    } catch (error) {
      console.error('Chyba pri získavaní dát z Jira:', error);
      process.exit(1);
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

function css(){
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
      svg {
        text-align: center;
        width: 100%;
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
function formatIssueLine(issue) {
    const status = issue.fields.status.name.padEnd(15);
    const assigneeValue = issue.fields.assignee?.displayName ?? 'Unassigned';
    const assignee = assigneeValue.padEnd(20);
    const key = issue.key.padEnd(10);
    const duedateValue = issue.fields.duedate ?? '-';
    const duedate = duedateValue.padEnd(10);
    const summary = truncate(issue.fields.summary, 68).padEnd(90);
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
  
    issues.forEach(issue => {
      const components = issue.fields.components.map(comp => comp.name);
      const status = issue.fields.status.name;
  
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
  const jql = `project = ${PROJECT_KEY} AND component = "${component}"`;
  const encodedURL = `${base}?jql=${encodeURIComponent(jql)}`;
  return `[${component}](${encodedURL})`;
}

 function pieSvg(summary) {
  const {totalSummary, componentSummary} = summary;
  const data = [
    { label: "🟠 Blocker",   value: totalSummary.blocker,   color: '#ff6723' },
    { label: "🟡 Waiting",   value: totalSummary.waiting,   color: '#fcd53f' },
    { label: "🔵 Executing", value: totalSummary.executing, color: '#0074ba' },
    { label: "🟢 Completed", value: totalSummary.completed, color: '#00d26a' },
  ];
  const svg = generatePieSVG(data);
  return svg;
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
  return `<svg width="400" height="200" viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">${parts.join('')}${legend.join('')}</svg>`;
}



function reportBuilder(summary, pie) {
  const {totalSummary, componentSummary} = summary;
  let message = ``;
  message += `<div id="report">\n\n`;
  message += `# Report projektu: ${PROJECT_KEY} | ⏱️ ${timestamp}\n\n`;
  message += `${pie}`;
  message += `\n\n`;

  let blockers = false;
  let categoryId = 0;

  Object.entries(jiraConfig.report).forEach(([groupName, components]) => {
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
  message += css();
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
  const issues = await getJiraIssues();
  const summary = summaryIssues(issues);
  const svg = pieSvg(summary);
  const report = reportBuilder(summary, svg);
  console.log(report);
  fs.mkdirSync('out', { recursive: true });
  fs.writeFileSync(`out/ispp-report.md`, report, 'utf8');
  fs.writeFileSync(`out/ispp-report-${timestamp}.md`, report, 'utf8');

 //await sendToDiscord(message);
}

main();
