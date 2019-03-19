using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;
using Microsoft.SqlServer;
namespace PleaseWork
{
    class Program
    {
        static void Main(string[] args)
        {
            Program p = new Program();
            p.RunScript();
            

        }
        public Program()
        {
            
        }
        private void RunScript()
        {
            // create Powershell runspace
            Runspace runspace = RunspaceFactory.CreateRunspace();

            // open it
            runspace.Open();

            // create a pipeline and feed it the script text
            Pipeline pipeline = runspace.CreatePipeline();

            string scriptFile = @"..//..//Scripts//CreateChangeScripts.ps1";
            string scriptText2 = LoadScript(scriptFile);
            pipeline.Commands.AddScript(scriptText2);

            // add an extra command to transform the script output objects into nicely formatted strings
            // remove this line to get the actual objects that the script returns. For example, the script
            // "Get-Process" returns a collection of System.Diagnostics.Process instances.
            pipeline.Commands.Add("Out-String");

            // execute the script
            Collection<PSObject> results = pipeline.Invoke();

            

            // close the runspace
            runspace.Close();
        
        }
        private string LoadScript(string filename)
        {
            try
            {
                using (StreamReader sr = new StreamReader(filename))
                {

                    StringBuilder fileContents = new StringBuilder();

                    string curLine;

                    while ((curLine = sr.ReadLine()) != null)
                    {
                        fileContents.Append(curLine + "\n");
                    }

                    return fileContents.ToString();
                }
            }
            catch (Exception e)
            {
                string errorText = "The file could not be read:";
                errorText += e.Message + "\n";
                return errorText;
            }
        }
    }
}
