
local NOTIFY_TYPES = {
    INFO = "^5[%s]^7-^6[INFO]^7 %s",
    SUCCESS = "^5[%s]^7-^2[SUCCESS]^7 %s",
    ERROR = "^5[%s]^7-^1[ERROR]^7 %s"
}

local function doesJobAndGradesExist(name, grades)
    local jobExists = ESX.Jobs[name] or false
    for _, grade in ipairs(grades) do
        if ESX.DoesJobExist(name, grade.grade) then
            jobExists = true
            break
        end
    end

    return jobExists
end

local function generateTransactionQueries(name,grades)
    local queries = {}
    for _, grade in ipairs(grades) do
        queries[#queries+1] = {
            query = 'INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)',
            values = {name, grade.grade, grade.name, grade.label, grade.salary, '{}', '{}'}
        }
    end

    return queries
end

local function generateNewJobTable(name, label, grades)
    local job = { name = name, label = label, grades = {} }
    for _, v in pairs(grades) do
        job.grades[tostring(v.grade)] = { job_name = name, grade = v.grade, name = v.name, label = v.label, salary = v.salary, skin_male = {}, skin_female = {} }
    end

    return job
end

local function notify(notifyType,resourceName,message,...)
    local formattedMessage = string.format(message, ...)

    if not NOTIFY_TYPES[notifyType] then
        return print(NOTIFY_TYPES.INFO:format(resourceName,formattedMessage))
    end

    return print(NOTIFY_TYPES[notifyType]:format(resourceName,formattedMessage))
end

--- Create Job at Runtime
--- @param name string
--- @param label string
--- @param grades table
function ESX.CreateJob(name, label, grades)
    local currentResourceName = GetInvokingResource()
    local success = false

    if not name or name == '' then
        notify("ERROR",currentResourceName, 'Missing argument `name`')
        return
    end
    if not label or label == '' then
        notify("ERROR",currentResourceName, 'Missing argument `label`')
        return
    end
    if not grades or not next(grades) then
        notify("ERROR",currentResourceName, 'Missing argument `grades`')
        return
    end

    local currentJobExist = doesJobAndGradesExist(name, grades)

    if currentJobExist then
        notify("ERROR",currentResourceName, 'Job already exists: `%s`', name)
        return
    end

    MySQL.insert('INSERT IGNORE INTO jobs (name, label) VALUES (?, ?)', {name, label}, function(jobId)
        if not jobId == 0 then
            notify("ERROR",currentResourceName, 'Failed to insert job: `%s`', name)
            return
        end

        local queries = generateTransactionQueries(name, grades)

        MySQL.transaction(queries, function(results)
            success = results
            if not results then
                notify("ERROR",currentResourceName, 'Failed to insert one or more grades for job: `%s`', name)
                return
            end

            ESX.Jobs[name] = generateNewJobTable(name,label,grades)
            notify("SUCCESS",currentResourceName, 'Job created successfully: `%s`', name)
        end)
    end)

    return success
end