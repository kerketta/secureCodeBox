const axios = require("axios");
const mustache = require("mustache");
// Read Synchrously
var fs = require("fs");

async function handle({
  getFindings,
  scan,
  webhookUrl = process.env["WEBHOOK_URL"],
}) {
  const findings = await getFindings();

  console.log(`Sending ${findings.length} findings to ${webhookUrl}`);
  console.log(scan);
  console.log(findings);

  const paylod = getMessageCardByTemplate(scan);

  await axios.post(webhookUrl, {paylod, findings });
}

/**
 * Returns a MS Teams WebHook Payload in the classic "MessageCard" style.
 * @param {*} scan 
 */
function getMessageCardByTemplate(scan) {
    let template = fs.readFileSync('messageCard.mustache');
    console.log("Output Content : \n"+ template);
    var rendered = mustache.render(template.toString(), { 
          uuid: scan.metadata.uid,
          scanType: scan.spec.scanType,
          name: scan.metadata.name,
          finishedAt: scan.status.finishedAt,
          severityFacts: getMessageCardFacts(scan.status.findings.severities),
          categoryFacts: getMessageCardFacts(scan.status.findings.categories) 
    });
    console.log("Output Rendered : \n"+ rendered);
    
    return rendered;
}

function getMessageCardFacts(facts)
{
    const result = [];
    for (var key in facts) {
        if (facts.hasOwnProperty(key)) {
            console.log(key + " -> " + facts[key]);
            result.push({
                "name": ""+key+"",
                "value": ""+facts[key]+""
            });
        }
    }
    //console.log("getMessageCardFacts Content : \n"+ JSON.stringify(result));
    return JSON.stringify(result);
}

module.exports.handle = handle;
module.exports.axios = axios;