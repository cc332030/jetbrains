
const fs = require('fs')
const child_process = require("child_process")

const username = 'c332030';
const command = `git config user.name ${username}`

function readSubDirThenDo(path, callback) {

    fs.readdir(path, (err, files) => {
        if(err) {
            console.log(err)
            return
        }

        // console.debug('files:', typeof files)
        //
        // if(files.contains('.git')) {
        //     callback(path);
        //     return
        // }

        if(files.includes('.git')) {
            callback(path);
            return
        }

        files.forEach(file => {

            const filePath = path + '/' + file
            fs.stat(filePath, (err, stats) => {

                if(err) {
                    console.log(err)
                    return
                }

                if(stats.isDirectory()) {
                    readSubDirThenDo(filePath, callback)
                }

            })
        })
    })

}

readSubDirThenDo(__dirname, (path) => {

    child_process.exec(command,{ cwd: path }, function(error, stdout, stderr) {
        if(error) {
            console.log(error)

        }
    });

})
